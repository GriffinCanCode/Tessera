#!/bin/bash
# Build C wrapper as shared library

set -e

echo "🔧 Building C wrapper for vector operations..."

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    EXT="dylib"
    FLAGS="-dynamiclib"
else
    # Linux
    EXT="so"
    FLAGS="-shared"
fi

# Create output directory
mkdir -p zig-out/lib

# Compile C wrapper as shared library
gcc -O3 -fPIC $FLAGS \
    -o zig-out/lib/libtessera_vector_ops.$EXT \
    lib/ffi/c_wrapper.c \
    -lm

echo "✅ C wrapper built: zig-out/lib/libtessera_vector_ops.$EXT"

# Test if library can be loaded
if [[ "$OSTYPE" == "darwin"* ]]; then
    otool -L zig-out/lib/libtessera_vector_ops.$EXT
else
    ldd zig-out/lib/libtessera_vector_ops.$EXT
fi

echo "🚀 Ready for Python integration!"
