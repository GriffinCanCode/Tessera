#!/usr/bin/env python3
"""
Integration test for Zig backend with all language components
Tests the complete multi-language performance stack
"""

import sys
import time
import numpy as np
from pathlib import Path

# Add paths for imports
sys.path.insert(0, str(Path(__file__).parent / "python"))
sys.path.insert(0, str(Path(__file__).parent.parent / "python-backend" / "src"))

def test_python_integration():
    """Test Python integration with Zig acceleration"""
    print("🐍 Testing Python integration...")
    
    try:
        from zig_vector_ops import zig_ops, benchmark_zig_vs_r
        
        if zig_ops.available:
            print("  ✅ Zig library loaded successfully")
            
            # Quick performance test
            query = np.random.randn(384).astype(np.float32)
            embeddings = np.random.randn(100, 384).astype(np.float32)
            
            # Normalize for proper cosine similarity
            query /= np.linalg.norm(query)
            embeddings /= np.linalg.norm(embeddings, axis=1, keepdims=True)
            
            start = time.time()
            results = zig_ops.batch_cosine_similarity(query, embeddings)
            zig_time = time.time() - start
            
            start = time.time()
            numpy_results = np.dot(embeddings, query)
            numpy_time = time.time() - start
            
            speedup = numpy_time / zig_time if zig_time > 0 else float('inf')
            accuracy = np.allclose(results, numpy_results, rtol=1e-5)
            
            print(f"  📊 Performance: {speedup:.1f}x speedup over NumPy")
            print(f"  🎯 Accuracy: {'✅ Pass' if accuracy else '❌ Fail'}")
            
            return True
        else:
            print("  ❌ Zig library not available")
            return False
            
    except Exception as e:
        print(f"  ❌ Python integration failed: {e}")
        return False

def test_perl_integration():
    """Test Perl integration (requires Perl to be available)"""
    print("🐪 Testing Perl integration...")
    
    try:
        import subprocess
        
        # Create a simple Perl test script
        perl_test = '''
use strict;
use warnings;
use lib "../zig-backend/perl";

eval {
    require ZigVectorOps;
    ZigVectorOps->import();
};

if ($@) {
    print "❌ Zig library not available: $@\\n";
    exit 1;
}

if (ZigVectorOps::is_available()) {
    print "✅ Zig library loaded successfully\\n";
    
    # Quick test
    my $vec1 = [1.0, 0.0, 0.0];
    my $vec2 = [1.0, 0.0, 0.0];
    my $similarity = ZigVectorOps::enhanced_cosine_similarity($vec1, $vec2);
    
    if (abs($similarity - 1.0) < 0.001) {
        print "🎯 Accuracy: ✅ Pass\\n";
        exit 0;
    } else {
        print "🎯 Accuracy: ❌ Fail (got $similarity, expected 1.0)\\n";
        exit 1;
    }
} else {
    print "❌ Zig library not available\\n";
    exit 1;
}
'''
        
        # Write and run the test
        test_file = Path(__file__).parent / "test_perl_integration.pl"
        test_file.write_text(perl_test)
        
        result = subprocess.run(['perl', str(test_file)], 
                              capture_output=True, text=True, 
                              cwd=Path(__file__).parent.parent / "perl-backend")
        
        print(f"  {result.stdout.strip()}")
        
        # Clean up
        test_file.unlink()
        
        return result.returncode == 0
        
    except Exception as e:
        print(f"  ❌ Perl integration test failed: {e}")
        return False

def test_r_integration():
    """Test R integration (requires R to be available)"""
    print("📊 Testing R integration...")
    
    try:
        import subprocess
        
        # Create R test script
        r_test = '''
# Test R integration with Zig
tryCatch({
    source("../zig-backend/r/zig_vector_ops.R")
    
    if (is_zig_available()) {
        cat("✅ Zig library loaded successfully\\n")
        
        # Quick test
        vec1 <- c(1.0, 0.0, 0.0)
        vec2 <- c(1.0, 0.0, 0.0)
        similarity <- enhanced_cosine_similarity(vec1, vec2)
        
        if (abs(similarity - 1.0) < 0.001) {
            cat("🎯 Accuracy: ✅ Pass\\n")
        } else {
            cat("🎯 Accuracy: ❌ Fail (got", similarity, ", expected 1.0)\\n")
            quit(status = 1)
        }
    } else {
        cat("❌ Zig library not available\\n")
        quit(status = 1)
    }
}, error = function(e) {
    cat("❌ R integration failed:", e$message, "\\n")
    quit(status = 1)
})
'''
        
        # Write and run the test
        test_file = Path(__file__).parent / "test_r_integration.R"
        test_file.write_text(r_test)
        
        result = subprocess.run(['Rscript', str(test_file)], 
                              capture_output=True, text=True,
                              cwd=Path(__file__).parent.parent / "r-backend")
        
        print(f"  {result.stdout.strip()}")
        
        # Clean up
        test_file.unlink()
        
        return result.returncode == 0
        
    except Exception as e:
        print(f"  ❌ R integration test failed: {e}")
        return False

def test_embedding_service_integration():
    """Test integration with actual embedding service"""
    print("🔍 Testing embedding service integration...")
    
    try:
        # Import the embedding service
        from embedding_service import EmbeddingService, EmbeddingSettings
        
        # Check if Zig acceleration is detected
        from embedding_service import ZIG_ACCELERATION_AVAILABLE
        
        if ZIG_ACCELERATION_AVAILABLE:
            print("  ✅ Embedding service detects Zig acceleration")
            return True
        else:
            print("  ❌ Embedding service does not detect Zig acceleration")
            return False
            
    except Exception as e:
        print(f"  ❌ Embedding service integration failed: {e}")
        return False

def main():
    """Run all integration tests"""
    print("🧪 Tessera Zig Integration Test Suite")
    print("=" * 50)
    
    tests = [
        ("Python Integration", test_python_integration),
        ("Perl Integration", test_perl_integration), 
        ("R Integration", test_r_integration),
        ("Embedding Service Integration", test_embedding_service_integration)
    ]
    
    results = []
    
    for test_name, test_func in tests:
        print(f"\n{test_name}:")
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"  💥 Test crashed: {e}")
            results.append((test_name, False))
    
    # Summary
    print("\n" + "=" * 50)
    print("📋 Test Results Summary:")
    
    passed = 0
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {test_name}: {status}")
        if result:
            passed += 1
    
    print(f"\n🎯 Overall: {passed}/{len(results)} tests passed")
    
    if passed == len(results):
        print("🎉 All integration tests passed! Zig acceleration is working across all languages.")
    else:
        print("⚠️  Some tests failed. Check individual results above.")
        
    return passed == len(results)

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
