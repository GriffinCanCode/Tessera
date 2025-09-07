# Tessera Zig Performance Backend

High-performance computational libraries for Tessera's multi-language architecture.

## 🎯 Purpose

Provides SIMD-optimized performance libraries that complement the existing backend services:
- **Vector Operations**: Ultra-fast cosine similarity for embedding search
- **Database Operations**: Optimized data processing utilities
- **FFI Integration**: Seamless integration with Python, Perl, and R backends

## 🏗️ Architecture

```
zig-backend/
├── build.zig              # Build configuration
├── lib/
│   ├── core/               # Core Zig modules
│   │   ├── vector_ops.zig  # SIMD vector operations
│   │   ├── db_ops.zig      # Database utilities
│   │   └── benchmark.zig   # Performance testing
│   ├── ffi/                # Foreign Function Interface bindings
│   │   ├── python/         # Python FFI wrapper
│   │   ├── perl/           # Perl FFI wrapper
│   │   └── r/              # R FFI wrapper
│   └── tests/              # Test modules
├── examples/               # Example code and integration tests
├── scripts/                # Build and utility scripts
└── docs/                   # Documentation
```

## 🚀 Quick Start

### Build Libraries

```bash
cd backend/zig-backend
./scripts/build.sh
```

This creates:
- `zig-out/lib/libtessera_vector_ops.so` - Vector operations
- `zig-out/lib/libtessera_db_ops.so` - Database utilities

### Run Benchmarks

```bash
zig build benchmark
```

### Run Tests

```bash
zig build test
```

## 📊 Performance

Optimized for Tessera's embedding dimensions (384D vectors):
- **10-100x faster** than pure Python/Perl implementations
- **SIMD vectorization** for parallel processing
- **Memory efficient** with zero-copy operations
- **Batch processing** for multiple similarities at once

## 🔌 Integration

### Python (embedding_service.py)
```python
# Import from FFI wrapper
from zig_vector_ops import batch_cosine_similarity, batch_similarity_with_threshold
```

### Perl (Storage.pm)
```perl
# Use the ZigVectorOps module
use ZigVectorOps;
my $similarity = ZigVectorOps::cosine_similarity($vec1, $vec2);
```

### R (graph_analysis.R)
```r
# Source the R wrapper
source("../zig-backend/lib/ffi/r/zig_vector_ops.R")
result <- enhanced_cosine_similarity(vec1, vec2)
```

## 🧪 Functions

### Vector Operations
- `cosine_similarity(vec1, vec2, len)` - Single similarity
- `batch_cosine_similarity(query, embeddings, count, dim, results)` - Batch processing
- `batch_similarity_with_threshold(...)` - Filtered batch processing
- `normalize_vector(vec, len)` - Vector normalization
- `vector_magnitude(vec, len)` - Calculate magnitude

### Database Operations
- `hash_content(content, result)` - Fast content hashing
- `validate_embedding_blob(blob, size)` - Blob validation

## 🔧 Development

Built with Zig's latest stable version for:
- **Memory safety** without garbage collection
- **C ABI compatibility** for easy FFI
- **Compile-time optimizations** and SIMD
- **Cross-platform** support (macOS, Linux, Windows)
