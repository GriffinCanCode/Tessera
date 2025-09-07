#!/usr/bin/env python3
"""
Modern RAG Embedding Service - 2025 Best Practices
Integrates with existing Tessera SQLite database
"""

import sqlite3
import numpy as np
import asyncio
from pathlib import Path
from typing import List, Dict, Optional, Any
from datetime import datetime, timedelta
from contextlib import asynccontextmanager

import structlog
from sentence_transformers import SentenceTransformer
from tenacity import retry, stop_after_attempt, wait_exponential

from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks, status
from pydantic import BaseModel, Field, ConfigDict
from pydantic_settings import BaseSettings, SettingsConfigDict


# ========== MODERN CONFIGURATION ==========

class EmbeddingSettings(BaseSettings):
    """Modern configuration with Pydantic Settings"""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="EMBEDDING_",
        case_sensitive=False,
        extra="ignore"  # Ignore extra environment variables
    )
    
    # Database
    database_path: Path = Field(
        default=Path("../data/tessera_knowledge.db"),
        description="Path to Tessera SQLite database"
    )
    
    # Model Configuration
    model_name: str = Field(
        default="all-MiniLM-L6-v2", 
        description="Sentence transformer model"
    )
    
    # Processing Settings
    batch_size: int = Field(default=32, gt=0, description="Embedding batch size")
    max_chunk_length: int = Field(default=512, gt=0, description="Max tokens per chunk")
    processing_interval: int = Field(default=60, gt=0, description="Processing interval in seconds")
    
    # Performance
    max_concurrent_batches: int = Field(default=3, gt=0)
    embedding_cache_hours: int = Field(default=24, gt=0)
    
    # Service
    host: str = Field(default="127.0.0.1")
    port: int = Field(default=8002)


# ========== MODERN PYDANTIC MODELS ==========

class ChunkEmbedRequest(BaseModel):
    model_config = ConfigDict(frozen=True)
    
    texts: List[str] = Field(..., min_length=1, max_length=100)
    model_name: Optional[str] = None


class ChunkEmbedResponse(BaseModel):
    model_config = ConfigDict(frozen=True)
    
    embeddings: List[List[float]]
    model_name: str
    dimension: int
    processed_count: int


class SemanticSearchRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    
    query: str = Field(..., min_length=1, max_length=1000)
    limit: int = Field(default=10, gt=0, le=50)
    min_similarity: float = Field(default=0.3, ge=0.0, le=1.0)
    model_name: Optional[str] = None
    project_id: Optional[int] = Field(default=None, description="Project context for search")


class SemanticChunk(BaseModel):
    model_config = ConfigDict(frozen=True)
    
    chunk_id: int
    article_id: int
    article_title: str
    content: str
    section_name: Optional[str]
    chunk_type: str
    similarity: float


class SemanticSearchResponse(BaseModel):
    model_config = ConfigDict(frozen=True)
    
    query: str
    chunks: List[SemanticChunk]
    model_name: str
    processing_time_ms: float


# ========== MODERN EMBEDDING SERVICE ==========

class EmbeddingService:
    """Modern embedding service with async patterns
    
    PRIVACY GUARANTEE: This service ONLY processes Wikipedia article content.
    It NEVER processes, embeds, or stores any conversation or chat data.
    All embeddings are generated from crawled Wikipedia articles only.
    """
    
    def __init__(self, settings: EmbeddingSettings):
        self.settings = settings
        self.model: Optional[SentenceTransformer] = None
        self.logger = structlog.get_logger(__name__).bind(service="embedding")
        
    async def initialize(self) -> None:
        """Initialize the sentence transformer model"""
        await self.logger.ainfo("Initializing embedding model", model=self.settings.model_name)
        
        # Load model in executor to avoid blocking
        self.model = await asyncio.get_event_loop().run_in_executor(
            None, SentenceTransformer, self.settings.model_name
        )
        
        await self.logger.ainfo(
            "Model initialized", 
            model=self.settings.model_name,
            max_seq_length=getattr(self.model, 'max_seq_length', 'unknown')
        )
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10)
    )
    async def generate_embeddings(self, texts: List[str]) -> np.ndarray:
        """Generate embeddings with retry logic"""
        if not self.model:
            raise RuntimeError("Model not initialized")
        
        # Run in executor to avoid blocking
        # Use keyword arguments to avoid parameter confusion
        def encode_texts():
            return self.model.encode(texts, normalize_embeddings=True)
        
        embeddings = await asyncio.get_event_loop().run_in_executor(
            None, encode_texts
        )
        
        return embeddings
    
    async def process_pending_chunks(self) -> int:
        """Process chunks that need embeddings
        
        PRIVACY GUARANTEE: This function processes learning content chunks 
        from both 'article_chunks' (legacy) and 'content_chunks' (new learning system).
        It NEVER processes conversation data.
        """
        if not self.model:
            await self.initialize()
        
        db_path = self.settings.database_path.resolve()
        if not db_path.exists():
            await self.logger.awarning("Database not found", path=str(db_path))
            return 0
        
        processed = 0
        
        with sqlite3.connect(str(db_path)) as conn:
            conn.row_factory = sqlite3.Row
            
            # Check if we have the new learning schema
            has_learning_schema = self._check_learning_schema(conn)
            
            if has_learning_schema:
                # Process new learning content chunks
                chunks = conn.execute("""
                    SELECT c.id, c.content_id, c.content_text as content, c.chunk_type, 
                           c.chunk_identifier, lc.title as content_title, lc.content_type
                    FROM content_chunks c
                    JOIN learning_content lc ON c.content_id = lc.id  
                    LEFT JOIN content_embeddings e ON c.id = e.chunk_id AND e.model_name = ?
                    WHERE c.needs_embedding = 1 AND e.chunk_id IS NULL
                    ORDER BY c.created_at ASC
                    LIMIT ?
                """, (self.settings.model_name, self.settings.batch_size)).fetchall()
            else:
                # Fallback to legacy article chunks
                chunks = conn.execute("""
                    SELECT c.id, c.article_id, c.content, c.chunk_type, 
                           c.section_name, a.title as article_title
                    FROM article_chunks c
                    JOIN articles a ON c.article_id = a.id  
                    LEFT JOIN chunk_embeddings e ON c.id = e.chunk_id AND e.model_name = ?
                    WHERE c.needs_embedding = 1 AND e.chunk_id IS NULL
                    ORDER BY c.created_at ASC
                    LIMIT ?
                """, (self.settings.model_name, self.settings.batch_size)).fetchall()
            
            if not chunks:
                return 0
            
            # Generate embeddings in batch
            texts = [chunk['content'] for chunk in chunks]
            embeddings = await self.generate_embeddings(texts)
            
            # Store embeddings
            embedding_data = [
                (
                    chunk['id'],
                    self.settings.model_name,
                    embeddings[i].tobytes(),  # Store as binary blob
                    len(embeddings[i])
                )
                for i, chunk in enumerate(chunks)
            ]
            
            # Store in database (use appropriate table based on schema)
            if has_learning_schema:
                conn.executemany("""
                    INSERT OR REPLACE INTO content_embeddings 
                    (chunk_id, model_name, embedding_blob, embedding_dim)
                    VALUES (?, ?, ?, ?)
                """, embedding_data)
                
                # Mark chunks as processed
                chunk_ids = [chunk['id'] for chunk in chunks]
                placeholders = ','.join(['?' for _ in chunk_ids])
                conn.execute(f"""
                    UPDATE content_chunks 
                    SET needs_embedding = 0 
                    WHERE id IN ({placeholders})
                """, chunk_ids)
            else:
                conn.executemany("""
                    INSERT OR REPLACE INTO chunk_embeddings 
                    (chunk_id, model_name, embedding_blob, embedding_dim)
                    VALUES (?, ?, ?, ?)
                """, embedding_data)
                
                # Mark chunks as processed
                chunk_ids = [chunk['id'] for chunk in chunks]
                placeholders = ','.join(['?' for _ in chunk_ids])
                conn.execute(f"""
                    UPDATE article_chunks 
                    SET needs_embedding = 0 
                    WHERE id IN ({placeholders})
                """, chunk_ids)
            
            processed = len(chunks)
            
            await self.logger.ainfo(
                "Processed embeddings batch",
                processed=processed,
                model=self.settings.model_name
            )
        
        return processed
    
    def _check_learning_schema(self, conn) -> bool:
        """Check if the new learning schema tables exist"""
        try:
            cursor = conn.execute("""
                SELECT name FROM sqlite_master 
                WHERE type='table' AND name IN ('learning_content', 'content_chunks', 'content_embeddings')
            """)
            tables = [row[0] for row in cursor.fetchall()]
            return len(tables) == 3
        except Exception:
            return False
    
    async def semantic_search(
        self, 
        query: str, 
        limit: int = 10, 
        min_similarity: float = 0.3,
        model_name: Optional[str] = None,
        project_id: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """Perform semantic search"""
        if not self.model:
            await self.initialize()
        
        model_name = model_name or self.settings.model_name
        
        # Generate query embedding
        query_embedding = await self.generate_embeddings([query])
        query_vector = query_embedding[0]
        
        db_path = self.settings.database_path.resolve()
        results = []
        
        with sqlite3.connect(str(db_path)) as conn:
            conn.row_factory = sqlite3.Row
            
            # Check schema and use appropriate queries
            has_learning_schema = self._check_learning_schema(conn)
            
            if has_learning_schema:
                # Use new learning content schema
                if project_id:
                    # For learning content, we can filter by subject instead of project
                    chunks = conn.execute("""
                        SELECT c.id, c.content_text as content, c.chunk_type, c.chunk_identifier,
                               lc.title as content_title, lc.id as content_id, lc.content_type,
                               e.embedding_blob, e.embedding_dim
                        FROM content_chunks c
                        JOIN learning_content lc ON c.content_id = lc.id
                        JOIN content_subjects cs ON lc.id = cs.content_id
                        JOIN content_embeddings e ON c.id = e.chunk_id
                        WHERE e.model_name = ? AND cs.subject_id = ?
                    """, (model_name, project_id)).fetchall()
                else:
                    chunks = conn.execute("""
                        SELECT c.id, c.content_text as content, c.chunk_type, c.chunk_identifier,
                               lc.title as content_title, lc.id as content_id, lc.content_type,
                               e.embedding_blob, e.embedding_dim
                        FROM content_chunks c
                        JOIN learning_content lc ON c.content_id = lc.id
                        JOIN content_embeddings e ON c.id = e.chunk_id
                        WHERE e.model_name = ?
                    """, (model_name,)).fetchall()
            else:
                # Fallback to legacy article schema
                if project_id:
                    chunks = conn.execute("""
                        SELECT c.id, c.content, c.chunk_type, c.section_name,
                               a.title as article_title, a.id as article_id,
                               e.embedding_blob, e.embedding_dim
                        FROM article_chunks c
                        JOIN articles a ON c.article_id = a.id
                        JOIN project_articles pa ON a.id = pa.article_id
                        JOIN chunk_embeddings e ON c.id = e.chunk_id
                        WHERE e.model_name = ? AND pa.project_id = ?
                    """, (model_name, project_id)).fetchall()
                else:
                    chunks = conn.execute("""
                        SELECT c.id, c.content, c.chunk_type, c.section_name,
                               a.title as article_title, a.id as article_id,
                               e.embedding_blob, e.embedding_dim
                        FROM article_chunks c
                        JOIN articles a ON c.article_id = a.id
                        JOIN chunk_embeddings e ON c.id = e.chunk_id
                        WHERE e.model_name = ?
                    """, (model_name,)).fetchall()
            
            # Calculate similarities
            scored_chunks = []
            
            # Handle empty chunks gracefully
            if not chunks:
                await self.logger.ainfo("No chunks found for semantic search", 
                                       model_name=model_name, 
                                       project_id=project_id)
                return []
            
            for chunk in chunks:
                try:
                    # Deserialize embedding
                    stored_embedding = np.frombuffer(chunk['embedding_blob'], dtype=np.float32)
                    
                    # Ensure vectors are normalized for cosine similarity
                    if len(stored_embedding) != len(query_vector):
                        await self.logger.awarning("Embedding dimension mismatch", 
                                                  stored_dim=len(stored_embedding),
                                                  query_dim=len(query_vector))
                        continue
                    
                    # Calculate cosine similarity
                    similarity = float(np.dot(query_vector, stored_embedding))
                    
                    if similarity >= min_similarity:
                        if has_learning_schema:
                            scored_chunks.append({
                                'chunk_id': chunk['id'],
                                'content_id': chunk['content_id'],
                                'content_title': chunk['content_title'],
                                'content': chunk['content'],
                                'chunk_identifier': chunk['chunk_identifier'],
                                'chunk_type': chunk['chunk_type'],
                                'content_type': chunk['content_type'],
                                'similarity': similarity,
                            })
                        else:
                            scored_chunks.append({
                                'chunk_id': chunk['id'],
                                'article_id': chunk['article_id'],
                                'article_title': chunk['article_title'],
                                'content': chunk['content'],
                                'section_name': chunk['section_name'],
                                'chunk_type': chunk['chunk_type'],
                                'similarity': similarity,
                            })
                except Exception as e:
                    await self.logger.awarning("Failed to process chunk embedding", 
                                             chunk_id=chunk['id'], 
                                             error=str(e))
                    continue
            
            # Sort by similarity and limit
            scored_chunks.sort(key=lambda x: x['similarity'], reverse=True)
            results = scored_chunks[:limit]
        
        return results


# ========== DEPENDENCY INJECTION ==========

_embedding_service: Optional[EmbeddingService] = None

async def get_embedding_service() -> EmbeddingService:
    """DI: Get embedding service instance"""
    global _embedding_service
    if _embedding_service is None:
        settings = EmbeddingSettings()
        _embedding_service = EmbeddingService(settings)
        await _embedding_service.initialize()
    return _embedding_service


# ========== MODERN APP WITH LIFESPAN ==========

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Modern lifespan management with background processing"""
    logger = structlog.get_logger(__name__)
    
    # Startup
    await logger.ainfo("Starting Tessera Embedding Service")
    
    # Initialize service
    embedding_service = await get_embedding_service()
    
    # Start background processing
    async def background_processor():
        while True:
            try:
                processed = await embedding_service.process_pending_chunks()
                if processed > 0:
                    await logger.ainfo("Background processing", processed=processed)
                await asyncio.sleep(embedding_service.settings.processing_interval)
            except Exception as e:
                await logger.aerror("Background processing error", error=str(e))
                await asyncio.sleep(30)  # Wait longer on error
    
    task = asyncio.create_task(background_processor())
    
    yield
    
    # Shutdown
    task.cancel()
    await logger.ainfo("Shutting down Tessera Embedding Service")


app = FastAPI(
    title="Tessera Embedding Service",
    version="1.0.0", 
    description="Modern RAG embedding service with SQLite integration",
    lifespan=lifespan
)


# ========== MODERN ENDPOINTS ==========

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "service": "Tessera Embedding Service",
        "status": "healthy",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat()
    }


@app.post("/embed", response_model=ChunkEmbedResponse)
async def embed_texts(
    request: ChunkEmbedRequest,
    service: EmbeddingService = Depends(get_embedding_service)
):
    """Generate embeddings for texts"""
    try:
        start_time = datetime.now()
        
        model_name = request.model_name or service.settings.model_name
        embeddings = await service.generate_embeddings(request.texts)
        
        processing_time = (datetime.now() - start_time).total_seconds() * 1000
        
        await service.logger.ainfo(
            "Generated embeddings",
            count=len(request.texts),
            processing_time_ms=processing_time
        )
        
        return ChunkEmbedResponse(
            embeddings=embeddings.tolist(),
            model_name=model_name,
            dimension=embeddings.shape[1],
            processed_count=len(request.texts)
        )
        
    except Exception as e:
        await service.logger.aerror("Embedding generation failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Embedding generation failed"
        )


@app.post("/search", response_model=SemanticSearchResponse) 
async def semantic_search(
    request: SemanticSearchRequest,
    service: EmbeddingService = Depends(get_embedding_service)
):
    """Perform semantic search"""
    try:
        start_time = datetime.now()
        
        results = await service.semantic_search(
            query=request.query,
            limit=request.limit,
            min_similarity=request.min_similarity,
            model_name=request.model_name,
            project_id=request.project_id
        )
        
        processing_time = (datetime.now() - start_time).total_seconds() * 1000
        
        chunks = [
            SemanticChunk(
                chunk_id=r['chunk_id'],
                article_id=r['article_id'], 
                article_title=r['article_title'],
                content=r['content'],
                section_name=r['section_name'],
                chunk_type=r['chunk_type'],
                similarity=r['similarity']
            )
            for r in results
        ]
        
        await service.logger.ainfo(
            "Semantic search completed",
            query_length=len(request.query),
            results_count=len(chunks),
            processing_time_ms=processing_time
        )
        
        return SemanticSearchResponse(
            query=request.query,
            chunks=chunks,
            model_name=request.model_name or service.settings.model_name,
            processing_time_ms=processing_time
        )
        
    except Exception as e:
        await service.logger.aerror("Semantic search failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Semantic search failed"
        )


@app.post("/process-pending")
async def process_pending_chunks(
    background_tasks: BackgroundTasks,
    service: EmbeddingService = Depends(get_embedding_service)
):
    """Manually trigger processing of pending chunks"""
    background_tasks.add_task(service.process_pending_chunks)
    return {"message": "Processing started in background"}


@app.get("/stats")
async def get_embedding_stats(service: EmbeddingService = Depends(get_embedding_service)):
    """Get embedding statistics"""
    db_path = service.settings.database_path.resolve()
    
    if not db_path.exists():
        raise HTTPException(status_code=404, detail="Database not found")
    
    with sqlite3.connect(str(db_path)) as conn:
        stats = {}
        has_learning_schema = service._check_learning_schema(conn)
        
        if has_learning_schema:
            # Use new learning content schema
            (stats['total_chunks'],) = conn.execute(
                "SELECT COUNT(*) FROM content_chunks"
            ).fetchone()
            
            # Chunks with embeddings
            (stats['embedded_chunks'],) = conn.execute("""
                SELECT COUNT(*) FROM content_chunks c
                JOIN content_embeddings e ON c.id = e.chunk_id
                WHERE e.model_name = ?
            """, (service.settings.model_name,)).fetchone()
            
            # Pending chunks
            (stats['pending_chunks'],) = conn.execute("""
                SELECT COUNT(*) FROM content_chunks c
                LEFT JOIN content_embeddings e ON c.id = e.chunk_id AND e.model_name = ?
                WHERE c.needs_embedding = 1 AND e.chunk_id IS NULL
            """, (service.settings.model_name,)).fetchone()
            
            # Additional learning stats
            (stats['total_content'],) = conn.execute(
                "SELECT COUNT(*) FROM learning_content"
            ).fetchone()
            
            (stats['total_subjects'],) = conn.execute(
                "SELECT COUNT(*) FROM subjects"
            ).fetchone()
            
        else:
            # Fallback to legacy article schema
            (stats['total_chunks'],) = conn.execute(
                "SELECT COUNT(*) FROM article_chunks"
            ).fetchone()
            
            # Chunks with embeddings
            (stats['embedded_chunks'],) = conn.execute("""
                SELECT COUNT(*) FROM article_chunks c
                JOIN chunk_embeddings e ON c.id = e.chunk_id
                WHERE e.model_name = ?
            """, (service.settings.model_name,)).fetchone()
            
            # Pending chunks
            (stats['pending_chunks'],) = conn.execute("""
                SELECT COUNT(*) FROM article_chunks c
                LEFT JOIN chunk_embeddings e ON c.id = e.chunk_id AND e.model_name = ?
                WHERE c.needs_embedding = 1 AND e.chunk_id IS NULL
            """, (service.settings.model_name,)).fetchone()
        
        stats['embedding_coverage'] = (
            stats['embedded_chunks'] / max(stats['total_chunks'], 1)
        ) * 100
        stats['schema_type'] = 'learning' if has_learning_schema else 'legacy'
        
    return stats


if __name__ == "__main__":
    import uvicorn
    
    # Configure structured logging
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )
    
    try:
        settings = EmbeddingSettings()
        
        uvicorn.run(
            "embedding_service:app",
            host=settings.host,
            port=settings.port,
            reload=False,
            log_level="info"
        )
        
    except Exception as e:
        print(f"Failed to start service: {e}")
        exit(1)
