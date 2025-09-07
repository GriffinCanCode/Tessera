#!/bin/bash
# Build script for Tessera Zig Performance Backend

set -e

echo "🚀 Building Tessera Zig Performance Libraries"
echo "=============================================="

# Check if Zig is available
if ! command -v zig &> /dev/null; then
    echo "❌ Zig not found. Please install Zig from https://ziglang.org/"
    exit 1
fi

echo "✅ Zig version: $(zig version)"

# Build the libraries
echo "🔨 Building vector operations library..."
zig build

# Check if build was successful
if [ -f "zig-out/lib/libtessera_vector_ops.so" ] || [ -f "zig-out/lib/libtessera_vector_ops.dylib" ]; then
    echo "✅ Vector operations library built successfully"
else
    echo "❌ Failed to build vector operations library"
    exit 1
fi

if [ -f "zig-out/lib/libtessera_db_ops.so" ] || [ -f "zig-out/lib/libtessera_db_ops.dylib" ]; then
    echo "✅ Database operations library built successfully"
else
    echo "❌ Failed to build database operations library"
    exit 1
fi

# Run tests
echo "🧪 Running tests..."
zig build test

# Run benchmark if requested
if [ "$1" = "--benchmark" ]; then
    echo "📊 Running performance benchmarks..."
    zig build benchmark
fi

echo ""
echo "🎉 Build complete! Libraries available at:"
echo "   - zig-out/lib/libtessera_vector_ops.so (or .dylib on macOS)"
echo "   - zig-out/lib/libtessera_db_ops.so (or .dylib on macOS)"
echo ""
echo "💡 Integration status:"
echo "   - Python: Import zig_vector_ops from python/ directory"
echo "   - Perl: Use ZigVectorOps module from perl/ directory"
echo "   - R: Load libraries with dyn.load()"
echo ""
echo "🚀 Ready for 10-100x performance boost in vector operations!"
