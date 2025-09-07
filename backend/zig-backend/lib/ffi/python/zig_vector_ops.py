#!/usr/bin/env python3
"""
Python FFI wrapper for Zig vector operations
Provides seamless integration with embedding_service.py
"""

import ctypes
import numpy as np
from pathlib import Path
from typing import List, Tuple, Optional
import structlog

logger = structlog.get_logger(__name__)

class ZigVectorOps:
    """High-performance vector operations using Zig backend"""
    
    def __init__(self, lib_path: Optional[str] = None):
        if lib_path is None:
            # Auto-detect library path relative to this file
            # From lib/ffi/python/ go up to zig-backend/ then to zig-out/lib/
            zig_backend = Path(__file__).parent.parent.parent.parent
            lib_dir = zig_backend / "zig-out" / "lib"
            
            # Try different extensions (macOS .dylib, Linux .so)
            for ext in [".dylib", ".so"]:
                candidate = lib_dir / f"libtessera_vector_ops{ext}"
                if candidate.exists():
                    lib_path = candidate
                    break
            else:
                # Better fallback - try .dylib first on macOS
                import platform
                if platform.system() == "Darwin":
                    lib_path = lib_dir / "libtessera_vector_ops.dylib"
                else:
                    lib_path = lib_dir / "libtessera_vector_ops.so"
        
        try:
            self.lib = ctypes.CDLL(str(lib_path))
            self._setup_functions()
            self.available = True
            logger.info("Zig vector operations loaded", lib_path=str(lib_path))
        except (OSError, AttributeError) as e:
            logger.warning("Zig vector operations not available, falling back to NumPy", 
                         error=str(e), lib_path=str(lib_path))
            self.available = False
    
    def _setup_functions(self):
        """Setup C function signatures"""
        
        # cosine_similarity(vec1, vec2, len) -> float
        self.lib.cosine_similarity.argtypes = [
            ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_float), 
            ctypes.c_size_t
        ]
        self.lib.cosine_similarity.restype = ctypes.c_float
        
        # batch_cosine_similarity(query, embeddings, num_embeddings, vector_dim, results)
        self.lib.batch_cosine_similarity.argtypes = [
            ctypes.POINTER(ctypes.c_float),  # query
            ctypes.POINTER(ctypes.c_float),  # embeddings
            ctypes.c_size_t,                 # num_embeddings
            ctypes.c_size_t,                 # vector_dim
            ctypes.POINTER(ctypes.c_float)   # results
        ]
        self.lib.batch_cosine_similarity.restype = None
        
        # batch_similarity_with_threshold(...)
        self.lib.batch_similarity_with_threshold.argtypes = [
            ctypes.POINTER(ctypes.c_float),  # query
            ctypes.POINTER(ctypes.c_float),  # embeddings
            ctypes.c_size_t,                 # num_embeddings
            ctypes.c_size_t,                 # vector_dim
            ctypes.c_float,                  # threshold
            ctypes.POINTER(ctypes.c_float),  # results
            ctypes.POINTER(ctypes.c_uint32)  # indices
        ]
        self.lib.batch_similarity_with_threshold.restype = ctypes.c_uint32
        
        # normalize_vector(vec, len)
        self.lib.normalize_vector.argtypes = [
            ctypes.POINTER(ctypes.c_float),
            ctypes.c_size_t
        ]
        self.lib.normalize_vector.restype = None
    
    def cosine_similarity(self, vec1: np.ndarray, vec2: np.ndarray) -> float:
        """Calculate cosine similarity between two vectors"""
        if not self.available:
            return float(np.dot(vec1, vec2))
        
        if len(vec1) != len(vec2):
            return 0.0
        
        # Ensure contiguous float32 arrays
        v1 = np.ascontiguousarray(vec1, dtype=np.float32)
        v2 = np.ascontiguousarray(vec2, dtype=np.float32)
        
        return self.lib.cosine_similarity(
            v1.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
            v2.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
            len(v1)
        )
    
    def batch_cosine_similarity(self, query: np.ndarray, embeddings: np.ndarray) -> np.ndarray:
        """Calculate cosine similarity between query and multiple embeddings
        
        Args:
            query: 1D array of shape (vector_dim,)
            embeddings: 2D array of shape (num_embeddings, vector_dim)
            
        Returns:
            1D array of similarities of shape (num_embeddings,)
        """
        if not self.available:
            # Fallback to NumPy
            return np.dot(embeddings, query)
        
        num_embeddings, vector_dim = embeddings.shape
        
        if len(query) != vector_dim:
            raise ValueError(f"Query dimension {len(query)} doesn't match embedding dimension {vector_dim}")
        
        # Ensure contiguous float32 arrays
        query_c = np.ascontiguousarray(query, dtype=np.float32)
        embeddings_c = np.ascontiguousarray(embeddings, dtype=np.float32)
        
        # Allocate results array
        results = np.zeros(num_embeddings, dtype=np.float32)
        
        self.lib.batch_cosine_similarity(
            query_c.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
            embeddings_c.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
            num_embeddings,
            vector_dim,
            results.ctypes.data_as(ctypes.POINTER(ctypes.c_float))
        )
        
        return results
    
    def batch_similarity_with_threshold(
        self, 
        query: np.ndarray, 
        embeddings: np.ndarray, 
        threshold: float = 0.3
    ) -> Tuple[np.ndarray, np.ndarray]:
        """Calculate similarities and filter by threshold
        
        Returns:
            Tuple of (similarities, indices) for results above threshold
        """
        if not self.available:
            # Fallback to NumPy
            similarities = np.dot(embeddings, query)
            mask = similarities >= threshold
            return similarities[mask], np.where(mask)[0]
        
        num_embeddings, vector_dim = embeddings.shape
        
        # Ensure contiguous float32 arrays
        query_c = np.ascontiguousarray(query, dtype=np.float32)
        embeddings_c = np.ascontiguousarray(embeddings, dtype=np.float32)
        
        # Allocate maximum possible results
        results = np.zeros(num_embeddings, dtype=np.float32)
        indices = np.zeros(num_embeddings, dtype=np.uint32)
        
        count = self.lib.batch_similarity_with_threshold(
            query_c.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
            embeddings_c.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
            num_embeddings,
            vector_dim,
            threshold,
            results.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
            indices.ctypes.data_as(ctypes.POINTER(ctypes.c_uint32))
        )
        
        # Return only the valid results
        return results[:count], indices[:count]
    
    def normalize_vector(self, vec: np.ndarray) -> np.ndarray:
        """Normalize vector in-place (modifies original array)"""
        if not self.available:
            norm = np.linalg.norm(vec)
            if norm > 0:
                vec /= norm
            return vec
        
        # Ensure contiguous float32 array
        vec_c = np.ascontiguousarray(vec, dtype=np.float32)
        
        self.lib.normalize_vector(
            vec_c.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
            len(vec_c)
        )
        
        return vec_c


# Global instance for easy importing
zig_ops = ZigVectorOps()

# Convenience functions
def cosine_similarity(vec1: np.ndarray, vec2: np.ndarray) -> float:
    """Calculate cosine similarity between two vectors"""
    return zig_ops.cosine_similarity(vec1, vec2)

def batch_cosine_similarity(query: np.ndarray, embeddings: np.ndarray) -> np.ndarray:
    """Calculate batch cosine similarities"""
    return zig_ops.batch_cosine_similarity(query, embeddings)

def batch_similarity_with_threshold(
    query: np.ndarray, 
    embeddings: np.ndarray, 
    threshold: float = 0.3
) -> Tuple[np.ndarray, np.ndarray]:
    """Calculate similarities with threshold filtering"""
    return zig_ops.batch_similarity_with_threshold(query, embeddings, threshold)


if __name__ == "__main__":
    # Quick test
    print("🧪 Testing Zig vector operations...")
    
    # Test data
    query = np.random.randn(384).astype(np.float32)
    embeddings = np.random.randn(100, 384).astype(np.float32)
    
    # Normalize for proper cosine similarity
    query /= np.linalg.norm(query)
    embeddings /= np.linalg.norm(embeddings, axis=1, keepdims=True)
    
    if zig_ops.available:
        import time
        
        # Benchmark
        start = time.time()
        results = batch_cosine_similarity(query, embeddings)
        zig_time = time.time() - start
        
        start = time.time()
        numpy_results = np.dot(embeddings, query)
        numpy_time = time.time() - start
        
        print(f"✅ Zig operations available!")
        print(f"   Zig time: {zig_time*1000:.2f}ms")
        print(f"   NumPy time: {numpy_time*1000:.2f}ms")
        print(f"   Speedup: {numpy_time/zig_time:.1f}x")
        print(f"   Results match: {np.allclose(results, numpy_results, rtol=1e-5)}")
    else:
        print("❌ Zig operations not available, using NumPy fallback")
