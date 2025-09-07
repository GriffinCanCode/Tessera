#!/usr/bin/env python3
"""
Database Connection Pool Manager for Tessera Python Services
Provides optimized SQLite connection pooling and caching
"""

import sqlite3
import threading
import time
from contextlib import contextmanager
from typing import Optional, Dict, Any, List
from pathlib import Path
import structlog
from dataclasses import dataclass
from queue import Queue, Empty

logger = structlog.get_logger(__name__)


@dataclass
class ConnectionStats:
    """Connection pool statistics"""
    total_connections: int = 0
    active_connections: int = 0
    idle_connections: int = 0
    total_requests: int = 0
    cache_hits: int = 0
    cache_misses: int = 0


class SQLiteConnectionPool:
    """Thread-safe SQLite connection pool with query caching"""
    
    def __init__(self, database_path: str, pool_size: int = 10, timeout: float = 30.0):
        self.database_path = Path(database_path).resolve()
        self.pool_size = pool_size
        self.timeout = timeout
        
        # Connection pool
        self._pool = Queue(maxsize=pool_size)
        self._all_connections = set()
        self._lock = threading.RLock()
        
        # Query cache
        self._query_cache: Dict[str, Any] = {}
        self._cache_lock = threading.RLock()
        self._cache_ttl = 300  # 5 minutes
        self._cache_timestamps: Dict[str, float] = {}
        
        # Statistics
        self.stats = ConnectionStats()
        
        # Initialize pool
        self._initialize_pool()
        
        logger.info("SQLite connection pool initialized", 
                   database=str(self.database_path), 
                   pool_size=pool_size)
    
    def _initialize_pool(self):
        """Initialize the connection pool"""
        for _ in range(self.pool_size):
            conn = self._create_connection()
            if conn:
                self._pool.put(conn)
                self._all_connections.add(conn)
                self.stats.total_connections += 1
    
    def _create_connection(self) -> Optional[sqlite3.Connection]:
        """Create a new SQLite connection with optimizations"""
        try:
            conn = sqlite3.connect(
                str(self.database_path),
                timeout=self.timeout,
                check_same_thread=False,  # Allow sharing between threads
                isolation_level=None  # Autocommit mode
            )
            
            # SQLite optimizations
            conn.execute("PRAGMA journal_mode=WAL")  # Write-Ahead Logging
            conn.execute("PRAGMA synchronous=NORMAL")  # Balanced durability/performance
            conn.execute("PRAGMA cache_size=10000")  # 10MB cache
            conn.execute("PRAGMA temp_store=MEMORY")  # Use memory for temp tables
            conn.execute("PRAGMA mmap_size=268435456")  # 256MB memory mapping
            
            # Row factory for dict-like access
            conn.row_factory = sqlite3.Row
            
            return conn
            
        except Exception as e:
            logger.error("Failed to create database connection", error=str(e))
            return None
    
    @contextmanager
    def get_connection(self):
        """Get a connection from the pool (context manager)"""
        conn = None
        try:
            # Try to get connection from pool
            try:
                conn = self._pool.get(timeout=self.timeout)
                self.stats.active_connections += 1
                self.stats.total_requests += 1
            except Empty:
                # Pool exhausted, create temporary connection
                logger.warning("Connection pool exhausted, creating temporary connection")
                conn = self._create_connection()
                if not conn:
                    raise Exception("Failed to create database connection")
            
            yield conn
            
        finally:
            if conn:
                self.stats.active_connections -= 1
                
                # Return to pool if it's a pooled connection
                if conn in self._all_connections:
                    try:
                        self._pool.put_nowait(conn)
                    except:
                        # Pool is full, this shouldn't happen but handle gracefully
                        pass
                else:
                    # Close temporary connection
                    conn.close()
    
    def execute_cached(self, query: str, params: tuple = (), cache_key: Optional[str] = None, 
                      ttl: int = 300) -> List[Dict[str, Any]]:
        """Execute query with caching support"""
        if not cache_key:
            cache_key = f"{hash(query)}_{hash(params)}"
        
        # Check cache first
        with self._cache_lock:
            if cache_key in self._query_cache:
                timestamp = self._cache_timestamps.get(cache_key, 0)
                if time.time() - timestamp < ttl:
                    self.stats.cache_hits += 1
                    logger.debug("Query cache hit", cache_key=cache_key)
                    return self._query_cache[cache_key]
                else:
                    # Expired
                    del self._query_cache[cache_key]
                    del self._cache_timestamps[cache_key]
        
        # Execute query
        self.stats.cache_misses += 1
        with self.get_connection() as conn:
            cursor = conn.execute(query, params)
            results = [dict(row) for row in cursor.fetchall()]
        
        # Cache results
        with self._cache_lock:
            self._query_cache[cache_key] = results
            self._cache_timestamps[cache_key] = time.time()
            
            # Cleanup old cache entries (simple LRU)
            if len(self._query_cache) > 1000:
                oldest_key = min(self._cache_timestamps.keys(), 
                               key=lambda k: self._cache_timestamps[k])
                del self._query_cache[oldest_key]
                del self._cache_timestamps[oldest_key]
        
        return results
    
    def execute(self, query: str, params: tuple = ()) -> List[Dict[str, Any]]:
        """Execute query without caching"""
        with self.get_connection() as conn:
            cursor = conn.execute(query, params)
            return [dict(row) for row in cursor.fetchall()]
    
    def execute_many(self, query: str, params_list: List[tuple]) -> int:
        """Execute query multiple times with different parameters"""
        with self.get_connection() as conn:
            cursor = conn.executemany(query, params_list)
            return cursor.rowcount
    
    def clear_cache(self, pattern: Optional[str] = None):
        """Clear query cache"""
        with self._cache_lock:
            if pattern:
                # Clear specific pattern (simple string matching)
                keys_to_remove = [k for k in self._query_cache.keys() if pattern in k]
                for key in keys_to_remove:
                    del self._query_cache[key]
                    if key in self._cache_timestamps:
                        del self._cache_timestamps[key]
            else:
                # Clear all
                self._query_cache.clear()
                self._cache_timestamps.clear()
        
        logger.info("Query cache cleared", pattern=pattern)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get connection pool statistics"""
        with self._lock:
            idle_connections = self._pool.qsize()
            return {
                "total_connections": self.stats.total_connections,
                "active_connections": self.stats.active_connections,
                "idle_connections": idle_connections,
                "total_requests": self.stats.total_requests,
                "cache_hits": self.stats.cache_hits,
                "cache_misses": self.stats.cache_misses,
                "cache_hit_ratio": (self.stats.cache_hits / max(1, self.stats.cache_hits + self.stats.cache_misses)),
                "cached_queries": len(self._query_cache)
            }
    
    def close(self):
        """Close all connections in the pool"""
        with self._lock:
            # Close all pooled connections
            while not self._pool.empty():
                try:
                    conn = self._pool.get_nowait()
                    conn.close()
                except Empty:
                    break
            
            # Close any remaining connections
            for conn in self._all_connections:
                try:
                    conn.close()
                except:
                    pass
            
            self._all_connections.clear()
            self.stats = ConnectionStats()
        
        logger.info("Database connection pool closed")


# Global connection pool instance
_connection_pool: Optional[SQLiteConnectionPool] = None
_pool_lock = threading.Lock()


def initialize_connection_pool(database_path: str, pool_size: int = 10) -> SQLiteConnectionPool:
    """Initialize the global connection pool"""
    global _connection_pool
    
    with _pool_lock:
        if _connection_pool is None:
            _connection_pool = SQLiteConnectionPool(database_path, pool_size)
        return _connection_pool


def get_connection_pool() -> SQLiteConnectionPool:
    """Get the global connection pool"""
    global _connection_pool
    
    if _connection_pool is None:
        raise RuntimeError("Connection pool not initialized. Call initialize_connection_pool() first.")
    
    return _connection_pool


# Convenience functions
def execute_query(query: str, params: tuple = (), cached: bool = False, 
                 cache_ttl: int = 300) -> List[Dict[str, Any]]:
    """Execute a query using the global connection pool"""
    pool = get_connection_pool()
    
    if cached:
        return pool.execute_cached(query, params, ttl=cache_ttl)
    else:
        return pool.execute(query, params)


def execute_many_queries(query: str, params_list: List[tuple]) -> int:
    """Execute multiple queries using the global connection pool"""
    pool = get_connection_pool()
    return pool.execute_many(query, params_list)


@contextmanager
def get_db_connection():
    """Get a database connection (context manager)"""
    pool = get_connection_pool()
    with pool.get_connection() as conn:
        yield conn


def get_pool_stats() -> Dict[str, Any]:
    """Get connection pool statistics"""
    pool = get_connection_pool()
    return pool.get_stats()


if __name__ == "__main__":
    # Test the connection pool
    import tempfile
    import os
    
    # Create test database
    with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as f:
        test_db = f.name
    
    try:
        # Initialize pool
        pool = initialize_connection_pool(test_db, pool_size=5)
        
        # Create test table
        with get_db_connection() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS test_table (
                    id INTEGER PRIMARY KEY,
                    name TEXT,
                    value INTEGER
                )
            """)
            
            # Insert test data
            conn.execute("INSERT INTO test_table (name, value) VALUES (?, ?)", ("test1", 100))
            conn.execute("INSERT INTO test_table (name, value) VALUES (?, ?)", ("test2", 200))
        
        # Test cached query
        results1 = execute_query("SELECT * FROM test_table WHERE value > ?", (50,), cached=True)
        results2 = execute_query("SELECT * FROM test_table WHERE value > ?", (50,), cached=True)
        
        print(f"Results: {results1}")
        print(f"Pool stats: {get_pool_stats()}")
        
        assert results1 == results2, "Cached results should be identical"
        
        stats = get_pool_stats()
        assert stats['cache_hits'] > 0, "Should have cache hits"
        
        print("✅ Connection pool test passed!")
        
    finally:
        # Cleanup
        if _connection_pool:
            _connection_pool.close()
        os.unlink(test_db)
