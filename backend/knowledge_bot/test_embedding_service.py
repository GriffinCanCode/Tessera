#!/usr/bin/env python3
"""
Comprehensive tests for the embedding service to debug semantic search failures
"""

import pytest
import asyncio
import sqlite3
import tempfile
import numpy as np
from pathlib import Path
from unittest.mock import Mock, patch, AsyncMock
import sys
import os

# Add the current directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from embedding_service import (
    EmbeddingService, 
    EmbeddingSettings,
    SemanticSearchRequest,
    ChunkEmbedRequest
)


class TestEmbeddingService:
    """Test suite for embedding service debugging"""
    
    @pytest.fixture
    async def temp_db(self):
        """Create a temporary database with test data"""
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        db_path = Path(temp_file.name)
        temp_file.close()
        
        # Create database schema
        with sqlite3.connect(str(db_path)) as conn:
            # Articles table
            conn.execute("""
                CREATE TABLE articles (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    title TEXT NOT NULL,
                    url TEXT UNIQUE NOT NULL,
                    content TEXT,
                    created_at INTEGER DEFAULT (strftime('%s', 'now')),
                    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
                )
            """)
            
            # Article chunks table
            conn.execute("""
                CREATE TABLE article_chunks (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    article_id INTEGER NOT NULL,
                    chunk_type TEXT NOT NULL,
                    section_name TEXT,
                    content TEXT NOT NULL,
                    char_count INTEGER,
                    token_count INTEGER,
                    content_hash TEXT,
                    needs_embedding INTEGER DEFAULT 1,
                    created_at INTEGER DEFAULT (strftime('%s', 'now')),
                    updated_at INTEGER DEFAULT (strftime('%s', 'now')),
                    FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE
                )
            """)
            
            # Chunk embeddings table
            conn.execute("""
                CREATE TABLE chunk_embeddings (
                    chunk_id INTEGER PRIMARY KEY,
                    model_name TEXT NOT NULL,
                    embedding_blob BLOB NOT NULL,
                    embedding_dim INTEGER NOT NULL,
                    created_at INTEGER DEFAULT (strftime('%s', 'now')),
                    FOREIGN KEY (chunk_id) REFERENCES article_chunks(id) ON DELETE CASCADE
                )
            """)
            
            # Insert test data
            conn.execute("""
                INSERT INTO articles (id, title, url, content) 
                VALUES (1, 'Test Article', 'https://test.com', 'Test content')
            """)
            
            conn.execute("""
                INSERT INTO article_chunks (id, article_id, chunk_type, content, needs_embedding)
                VALUES (1, 1, 'paragraph', 'This is a test chunk about machine learning', 1)
            """)
            
            conn.execute("""
                INSERT INTO article_chunks (id, article_id, chunk_type, content, needs_embedding)
                VALUES (2, 1, 'paragraph', 'This chunk discusses artificial intelligence', 1)
            """)
            
            conn.commit()
        
        yield db_path
        
        # Cleanup
        db_path.unlink(missing_ok=True)
    
    @pytest.fixture
    def embedding_settings(self, temp_db):
        """Create test settings"""
        return EmbeddingSettings(
            database_path=temp_db,
            model_name="all-MiniLM-L6-v2",
            batch_size=2,
            processing_interval=1
        )
    
    @pytest.fixture
    async def embedding_service(self, embedding_settings):
        """Create embedding service instance"""
        service = EmbeddingService(embedding_settings)
        return service
    
    async def test_service_initialization(self, embedding_service):
        """Test that the service initializes correctly"""
        assert embedding_service.model is None
        
        await embedding_service.initialize()
        
        assert embedding_service.model is not None
        assert hasattr(embedding_service.model, 'encode')
    
    async def test_generate_embeddings_basic(self, embedding_service):
        """Test basic embedding generation"""
        await embedding_service.initialize()
        
        texts = ["Hello world", "Machine learning is fascinating"]
        embeddings = await embedding_service.generate_embeddings(texts)
        
        assert embeddings.shape[0] == 2  # Two texts
        assert embeddings.shape[1] > 0   # Has dimensions
        assert embeddings.dtype == np.float32
    
    async def test_generate_embeddings_empty_input(self, embedding_service):
        """Test embedding generation with empty input"""
        await embedding_service.initialize()
        
        with pytest.raises(Exception):
            await embedding_service.generate_embeddings([])
    
    async def test_generate_embeddings_uninitialized_model(self, embedding_service):
        """Test embedding generation without model initialization"""
        with pytest.raises(RuntimeError, match="Model not initialized"):
            await embedding_service.generate_embeddings(["test"])
    
    async def test_process_pending_chunks_no_db(self, embedding_settings):
        """Test processing when database doesn't exist"""
        # Point to non-existent database
        embedding_settings.database_path = Path("/nonexistent/path.db")
        service = EmbeddingService(embedding_settings)
        
        result = await service.process_pending_chunks()
        assert result == 0
    
    async def test_process_pending_chunks_success(self, embedding_service, temp_db):
        """Test successful processing of pending chunks"""
        await embedding_service.initialize()
        
        # Verify chunks need embedding
        with sqlite3.connect(str(temp_db)) as conn:
            count = conn.execute(
                "SELECT COUNT(*) FROM article_chunks WHERE needs_embedding = 1"
            ).fetchone()[0]
            assert count == 2
        
        # Process chunks
        processed = await embedding_service.process_pending_chunks()
        assert processed == 2
        
        # Verify embeddings were created
        with sqlite3.connect(str(temp_db)) as conn:
            embedding_count = conn.execute(
                "SELECT COUNT(*) FROM chunk_embeddings"
            ).fetchone()[0]
            assert embedding_count == 2
            
            # Verify chunks are marked as processed
            pending_count = conn.execute(
                "SELECT COUNT(*) FROM article_chunks WHERE needs_embedding = 1"
            ).fetchone()[0]
            assert pending_count == 0
    
    async def test_semantic_search_no_embeddings(self, embedding_service, temp_db):
        """Test semantic search when no embeddings exist"""
        await embedding_service.initialize()
        
        results = await embedding_service.semantic_search("machine learning")
        assert results == []
    
    async def test_semantic_search_with_embeddings(self, embedding_service, temp_db):
        """Test semantic search after processing embeddings"""
        await embedding_service.initialize()
        
        # Process embeddings first
        await embedding_service.process_pending_chunks()
        
        # Perform search
        results = await embedding_service.semantic_search("machine learning", limit=5)
        
        assert len(results) > 0
        assert all('similarity' in result for result in results)
        assert all('content' in result for result in results)
        assert all(result['similarity'] >= 0 for result in results)
    
    async def test_semantic_search_similarity_threshold(self, embedding_service, temp_db):
        """Test semantic search with similarity threshold"""
        await embedding_service.initialize()
        await embedding_service.process_pending_chunks()
        
        # Search with high threshold
        results = await embedding_service.semantic_search(
            "completely unrelated topic xyz", 
            min_similarity=0.9
        )
        
        # Should return fewer or no results due to high threshold
        assert len(results) <= 2
    
    async def test_embedding_dimension_consistency(self, embedding_service):
        """Test that embeddings have consistent dimensions"""
        await embedding_service.initialize()
        
        texts1 = ["First batch"]
        texts2 = ["Second batch", "Third item"]
        
        embeddings1 = await embedding_service.generate_embeddings(texts1)
        embeddings2 = await embedding_service.generate_embeddings(texts2)
        
        assert embeddings1.shape[1] == embeddings2.shape[1]
    
    async def test_database_connection_error_handling(self, embedding_settings):
        """Test handling of database connection errors"""
        # Create service with invalid database path
        embedding_settings.database_path = Path("/invalid/path/db.sqlite")
        service = EmbeddingService(embedding_settings)
        
        # Should handle gracefully
        result = await service.process_pending_chunks()
        assert result == 0
    
    async def test_corrupted_embedding_handling(self, embedding_service, temp_db):
        """Test handling of corrupted embeddings in database"""
        await embedding_service.initialize()
        
        # Insert corrupted embedding data
        with sqlite3.connect(str(temp_db)) as conn:
            conn.execute("""
                INSERT INTO chunk_embeddings (chunk_id, model_name, embedding_blob, embedding_dim)
                VALUES (1, 'all-MiniLM-L6-v2', ?, 384)
            """, (b"corrupted_data",))
        
        # Should handle gracefully and not crash
        results = await embedding_service.semantic_search("test query")
        # May return empty results or skip corrupted embeddings
        assert isinstance(results, list)
    
    async def test_model_loading_failure(self):
        """Test handling of model loading failures"""
        settings = EmbeddingSettings(model_name="nonexistent-model-xyz")
        service = EmbeddingService(settings)
        
        # Should raise an exception or handle gracefully
        with pytest.raises(Exception):
            await service.initialize()
    
    async def test_large_text_handling(self, embedding_service):
        """Test handling of very large text inputs"""
        await embedding_service.initialize()
        
        # Create very long text
        large_text = "This is a test. " * 1000  # Very long text
        
        try:
            embeddings = await embedding_service.generate_embeddings([large_text])
            assert embeddings.shape[0] == 1
        except Exception as e:
            # Should handle gracefully, not crash
            assert "length" in str(e).lower() or "token" in str(e).lower()


class TestEmbeddingServiceIntegration:
    """Integration tests for the embedding service"""
    
    async def test_full_workflow(self, temp_db):
        """Test the complete embedding workflow"""
        settings = EmbeddingSettings(
            database_path=temp_db,
            model_name="all-MiniLM-L6-v2"
        )
        service = EmbeddingService(settings)
        
        # Initialize
        await service.initialize()
        
        # Process pending chunks
        processed = await service.process_pending_chunks()
        assert processed > 0
        
        # Perform search
        results = await service.semantic_search("machine learning")
        assert len(results) > 0
        
        # Verify result structure
        for result in results:
            assert 'chunk_id' in result
            assert 'article_id' in result
            assert 'content' in result
            assert 'similarity' in result
            assert isinstance(result['similarity'], float)
    
    async def test_concurrent_operations(self, embedding_service, temp_db):
        """Test concurrent embedding operations"""
        await embedding_service.initialize()
        
        # Run multiple operations concurrently
        tasks = [
            embedding_service.process_pending_chunks(),
            embedding_service.generate_embeddings(["test1", "test2"]),
            embedding_service.generate_embeddings(["test3", "test4"])
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Should complete without exceptions
        for result in results:
            assert not isinstance(result, Exception)


async def run_diagnostic_tests():
    """Run diagnostic tests to identify embedding service issues"""
    print("🔍 Running Embedding Service Diagnostic Tests...")
    
    # Test 1: Check if sentence-transformers is working
    print("\n1. Testing sentence-transformers installation...")
    try:
        from sentence_transformers import SentenceTransformer
        model = SentenceTransformer('all-MiniLM-L6-v2')
        test_embedding = model.encode(["Hello world"])
        print(f"✅ Sentence transformers working. Embedding shape: {test_embedding.shape}")
    except Exception as e:
        print(f"❌ Sentence transformers error: {e}")
        return
    
    # Test 2: Check database connectivity
    print("\n2. Testing database connectivity...")
    db_path = Path("../data/wiki_knowledge.db").resolve()
    if not db_path.exists():
        print(f"❌ Database not found at: {db_path}")
        return
    
    try:
        with sqlite3.connect(str(db_path)) as conn:
            # Check if tables exist
            tables = conn.execute("""
                SELECT name FROM sqlite_master 
                WHERE type='table' AND name IN ('article_chunks', 'chunk_embeddings')
            """).fetchall()
            print(f"✅ Database accessible. Found tables: {[t[0] for t in tables]}")
            
            # Check chunk counts
            chunk_count = conn.execute("SELECT COUNT(*) FROM article_chunks").fetchone()[0]
            embedding_count = conn.execute("SELECT COUNT(*) FROM chunk_embeddings").fetchone()[0]
            pending_count = conn.execute("""
                SELECT COUNT(*) FROM article_chunks c
                LEFT JOIN chunk_embeddings e ON c.id = e.chunk_id
                WHERE c.needs_embedding = 1 AND e.chunk_id IS NULL
            """).fetchone()[0]
            
            print(f"📊 Chunks: {chunk_count}, Embeddings: {embedding_count}, Pending: {pending_count}")
            
    except Exception as e:
        print(f"❌ Database error: {e}")
        return
    
    # Test 3: Test embedding service initialization
    print("\n3. Testing embedding service initialization...")
    try:
        settings = EmbeddingSettings(database_path=db_path)
        service = EmbeddingService(settings)
        await service.initialize()
        print("✅ Embedding service initialized successfully")
        
        # Test embedding generation
        test_embeddings = await service.generate_embeddings(["Test text"])
        print(f"✅ Embedding generation working. Shape: {test_embeddings.shape}")
        
    except Exception as e:
        print(f"❌ Embedding service error: {e}")
        import traceback
        traceback.print_exc()
        return
    
    # Test 4: Test semantic search
    print("\n4. Testing semantic search...")
    try:
        results = await service.semantic_search("artificial intelligence", limit=3)
        print(f"✅ Semantic search completed. Found {len(results)} results")
        
        if results:
            print("Sample result:")
            sample = results[0]
            print(f"  - Chunk ID: {sample.get('chunk_id')}")
            print(f"  - Similarity: {sample.get('similarity', 0):.3f}")
            print(f"  - Content preview: {sample.get('content', '')[:100]}...")
        
    except Exception as e:
        print(f"❌ Semantic search error: {e}")
        import traceback
        traceback.print_exc()
        return
    
    print("\n🎉 All diagnostic tests completed!")


if __name__ == "__main__":
    # Run diagnostic tests
    asyncio.run(run_diagnostic_tests())
