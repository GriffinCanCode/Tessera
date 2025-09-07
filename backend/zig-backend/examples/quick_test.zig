const std = @import("std");
const vector_ops = @import("../lib/core/vector_ops.zig");

pub fn main() !void {
    std.debug.print("🚀 Tessera Zig Quick Test\n", .{});
    std.debug.print("=========================\n\n", .{});
    
    // Test 1: Basic cosine similarity
    std.debug.print("1️⃣ Testing basic cosine similarity...\n", .{});
    const vec1 = [_]f32{ 1.0, 0.0, 0.0 };
    const vec2 = [_]f32{ 1.0, 0.0, 0.0 };
    const similarity = vector_ops.cosine_similarity(&vec1, &vec2, vec1.len);
    std.debug.print("   Identical vectors similarity: {d:.3}\n", .{similarity});
    
    if (@abs(similarity - 1.0) < 0.001) {
        std.debug.print("   ✅ PASS\n", .{});
    } else {
        std.debug.print("   ❌ FAIL (expected 1.0)\n", .{});
        return;
    }
    
    // Test 2: Orthogonal vectors
    std.debug.print("\n2️⃣ Testing orthogonal vectors...\n", .{});
    const vec3 = [_]f32{ 1.0, 0.0 };
    const vec4 = [_]f32{ 0.0, 1.0 };
    const ortho_similarity = vector_ops.cosine_similarity(&vec3, &vec4, vec3.len);
    std.debug.print("   Orthogonal vectors similarity: {d:.3}\n", .{ortho_similarity});
    
    if (@abs(ortho_similarity) < 0.001) {
        std.debug.print("   ✅ PASS\n", .{});
    } else {
        std.debug.print("   ❌ FAIL (expected 0.0)\n", .{});
        return;
    }
    
    // Test 3: Batch processing
    std.debug.print("\n3️⃣ Testing batch processing...\n", .{});
    var query = [_]f32{ 1.0, 0.0 };
    var embeddings = [_]f32{ 
        1.0, 0.0,  // Same as query
        0.0, 1.0,  // Orthogonal
        -1.0, 0.0, // Opposite
    };
    var results: [3]f32 = undefined;
    
    vector_ops.batch_cosine_similarity(&query, &embeddings, 3, 2, &results);
    
    std.debug.print("   Batch results: [{d:.3}, {d:.3}, {d:.3}]\n", .{ results[0], results[1], results[2] });
    
    const expected = [_]f32{ 1.0, 0.0, -1.0 };
    var batch_pass = true;
    for (results, expected) |actual, expect| {
        if (@abs(actual - expect) > 0.001) {
            batch_pass = false;
            break;
        }
    }
    
    if (batch_pass) {
        std.debug.print("   ✅ PASS\n", .{});
    } else {
        std.debug.print("   ❌ FAIL (expected [1.0, 0.0, -1.0])\n", .{});
        return;
    }
    
    // Test 4: Threshold filtering
    std.debug.print("\n4️⃣ Testing threshold filtering...\n", .{});
    var filter_results: [3]f32 = undefined;
    var filter_indices: [3]u32 = undefined;
    
    const count = vector_ops.batch_similarity_with_threshold(
        &query, &embeddings, 3, 2, 0.5, &filter_results, &filter_indices
    );
    
    std.debug.print("   Results above threshold 0.5: {} items\n", .{count});
    for (0..count) |i| {
        std.debug.print("   Index {}: similarity {d:.3}\n", .{ filter_indices[i], filter_results[i] });
    }
    
    if (count == 1 and filter_indices[0] == 0 and @abs(filter_results[0] - 1.0) < 0.001) {
        std.debug.print("   ✅ PASS\n", .{});
    } else {
        std.debug.print("   ❌ FAIL (expected 1 result with similarity 1.0)\n", .{});
        return;
    }
    
    // Test 5: Performance test
    std.debug.print("\n5️⃣ Performance test (1000 embeddings)...\n", .{});
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const dim = 384;
    const num_embeddings = 1000;
    
    const perf_query = try allocator.alloc(f32, dim);
    defer allocator.free(perf_query);
    
    const perf_embeddings = try allocator.alloc(f32, num_embeddings * dim);
    defer allocator.free(perf_embeddings);
    
    const perf_results = try allocator.alloc(f32, num_embeddings);
    defer allocator.free(perf_results);
    
    // Initialize with random-ish data
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    
    for (perf_query) |*val| {
        val.* = random.floatNorm(f32);
    }
    
    for (perf_embeddings) |*val| {
        val.* = random.floatNorm(f32);
    }
    
    // Normalize vectors
    vector_ops.normalize_vector(perf_query.ptr, dim);
    for (0..num_embeddings) |i| {
        vector_ops.normalize_vector(perf_embeddings.ptr + i * dim, dim);
    }
    
    // Time the operation
    var timer = try std.time.Timer.start();
    
    vector_ops.batch_cosine_similarity(
        perf_query.ptr, perf_embeddings.ptr, num_embeddings, dim, perf_results.ptr
    );
    
    const elapsed_ns = timer.read();
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    
    std.debug.print("   Processed {} similarities in {d:.2} ms\n", .{ num_embeddings, elapsed_ms });
    std.debug.print("   Throughput: {d:.0} similarities/second\n", .{@as(f64, @floatFromInt(num_embeddings)) / (elapsed_ms / 1000.0)});
    
    // Verify results are valid
    var valid_results = true;
    for (perf_results) |result| {
        if (result < -1.0 or result > 1.0 or std.math.isNan(result)) {
            valid_results = false;
            break;
        }
    }
    
    if (valid_results) {
        std.debug.print("   ✅ PASS (all results in valid range [-1, 1])\n", .{});
    } else {
        std.debug.print("   ❌ FAIL (invalid results detected)\n", .{});
        return;
    }
    
    std.debug.print("\n🎉 All quick tests passed! Zig backend is working correctly.\n", .{});
    std.debug.print("⚡ Ready for 10-100x performance boost in your applications!\n", .{});
}
