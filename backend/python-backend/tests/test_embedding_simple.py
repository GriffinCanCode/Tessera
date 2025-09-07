#!/usr/bin/env python3
"""
Simple tests for embedding service to verify the fix works
"""

import asyncio
import sqlite3
import tempfile
import numpy as np
from pathlib import Path
import sys
import os

# Add the current directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from src.services.embedding_service import EmbeddingService, EmbeddingSettings


def create_test_db():
    """Create a temporary test database"""
    temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
    db_path = Path(temp_file.name)
    temp_file.close()
    
    with sqlite3.connect(str(db_path)) as conn:
        # Create schema
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
            VALUES (1, 'Machine Learning', 'https://test.com/ml', 'ML content')
        """)
        
        conn.execute("""
            INSERT INTO article_chunks (id, article_id, chunk_type, content, needs_embedding)
            VALUES (1, 1, 'paragraph', 'Machine learning is a subset of artificial intelligence', 1)
        """)
        
        conn.execute("""
            INSERT INTO article_chunks (id, article_id, chunk_type, content, needs_embedding)
            VALUES (2, 1, 'paragraph', 'Deep learning uses neural networks with multiple layers', 1)
        """)
        
        conn.commit()
    
    return db_path


async def test_embedding_generation():
    """Test basic embedding generation"""
    print("🧪 Testing embedding generation...")
    
    settings = EmbeddingSettings(model_name="all-MiniLM-L6-v2")
    service = EmbeddingService(settings)
    
    await service.initialize()
    
    texts = ["Hello world", "Machine learning is fascinating"]
    embeddings = await service.generate_embeddings(texts)
    
    assert embeddings.shape[0] == 2, f"Expected 2 embeddings, got {embeddings.shape[0]}"
    assert embeddings.shape[1] > 0, f"Expected positive dimensions, got {embeddings.shape[1]}"
    assert embeddings.dtype == np.float32, f"Expected float32, got {embeddings.dtype}"
    
    print(f"✅ Generated embeddings with shape: {embeddings.shape}")


async def test_process_chunks():
    """Test processing chunks from database"""
    print("🧪 Testing chunk processing...")
    
    db_path = create_test_db()
    
    try:
        settings = EmbeddingSettings(
            database_path=db_path,
            model_name="all-MiniLM-L6-v2",
            batch_size=10
        )
        service = EmbeddingService(settings)
        
        await service.initialize()
        
        # Process chunks
        processed = await service.process_pending_chunks()
        
        assert processed == 2, f"Expected to process 2 chunks, got {processed}"
        
        # Verify embeddings were stored
        with sqlite3.connect(str(db_path)) as conn:
            embedding_count = conn.execute("SELECT COUNT(*) FROM chunk_embeddings").fetchone()[0]
            assert embedding_count == 2, f"Expected 2 embeddings in DB, got {embedding_count}"
            
            # Verify chunks are no longer pending
            pending_count = conn.execute(
                "SELECT COUNT(*) FROM article_chunks WHERE needs_embedding = 1"
            ).fetchone()[0]
            assert pending_count == 0, f"Expected 0 pending chunks, got {pending_count}"
        
        print(f"✅ Successfully processed {processed} chunks")
        
    finally:
        db_path.unlink(missing_ok=True)


async def test_semantic_search():
    """Test semantic search functionality"""
    print("🧪 Testing semantic search...")
    
    db_path = create_test_db()
    
    try:
        settings = EmbeddingSettings(
            database_path=db_path,
            model_name="all-MiniLM-L6-v2"
        )
        service = EmbeddingService(settings)
        
        await service.initialize()
        
        # First process the chunks
        await service.process_pending_chunks()
        
        # Now search
        results = await service.semantic_search("artificial intelligence", limit=5)
        
        assert len(results) > 0, "Expected to find some results"
        
        for result in results:
            assert 'similarity' in result, "Result should have similarity score"
            assert 'content' in result, "Result should have content"
            assert 'chunk_id' in result, "Result should have chunk_id"
            assert isinstance(result['similarity'], float), "Similarity should be float"
            assert 0 <= result['similarity'] <= 1, f"Similarity should be 0-1, got {result['similarity']}"
        
        print(f"✅ Found {len(results)} search results")
        if results:
            print(f"   Best match similarity: {results[0]['similarity']:.3f}")
        
    finally:
        db_path.unlink(missing_ok=True)


async def test_error_handling():
    """Test error handling scenarios"""
    print("🧪 Testing error handling...")
    
    # Test uninitialized model
    settings = EmbeddingSettings(model_name="all-MiniLM-L6-v2")
    service = EmbeddingService(settings)
    
    try:
        await service.generate_embeddings(["test"])
        assert False, "Should have raised RuntimeError"
    except RuntimeError as e:
        assert "not initialized" in str(e)
        print("✅ Correctly handled uninitialized model")
    
    # Test non-existent database
    settings = EmbeddingSettings(database_path=Path("/nonexistent/path.db"))
    service = EmbeddingService(settings)
    
    result = await service.process_pending_chunks()
    assert result == 0, f"Expected 0 for non-existent DB, got {result}"
    print("✅ Correctly handled non-existent database")


async def main():
    """Run all tests"""
    print("🚀 Starting Embedding Service Tests...")
    print("=" * 50)
    
    try:
        await test_embedding_generation()
        await test_process_chunks()
        await test_semantic_search()
        await test_error_handling()
        
        print("=" * 50)
        print("🎉 All tests passed! Embedding service is working correctly.")
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    exit(exit_code)
