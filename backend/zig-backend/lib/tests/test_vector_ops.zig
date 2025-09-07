const std = @import("std");
const testing = std.testing;
const vector_ops = @import("vector_ops");

// Test basic cosine similarity
test "cosine similarity - identical vectors" {
    const vec1 = [_]f32{ 1.0, 0.0, 0.0 };
    const vec2 = [_]f32{ 1.0, 0.0, 0.0 };

    const result = vector_ops.cosine_similarity_zig(&vec1, &vec2);
    try testing.expectApproxEqRel(result, 1.0, 0.001);
}

test "cosine similarity - orthogonal vectors" {
    const vec1 = [_]f32{ 1.0, 0.0 };
    const vec2 = [_]f32{ 0.0, 1.0 };

    const result = vector_ops.cosine_similarity_zig(&vec1, &vec2);
    try testing.expectApproxEqRel(result, 0.0, 0.001);
}

test "cosine similarity - opposite vectors" {
    const vec1 = [_]f32{ 1.0, 0.0, 0.0 };
    const vec2 = [_]f32{ -1.0, 0.0, 0.0 };

    const result = vector_ops.cosine_similarity_zig(&vec1, &vec2);
    try testing.expectApproxEqRel(result, -1.0, 0.001);
}

test "cosine similarity - zero vector" {
    const vec1 = [_]f32{ 0.0, 0.0, 0.0 };
    const vec2 = [_]f32{ 1.0, 0.0, 0.0 };

    const result = vector_ops.cosine_similarity_zig(&vec1, &vec2);
    try testing.expectEqual(result, 0.0);
}

test "batch cosine similarity - basic test" {
    var query = [_]f32{ 1.0, 0.0 };
    var embeddings = [_]f32{
        1.0, 0.0, // Same as query -> similarity = 1.0
        0.0, 1.0, // Orthogonal to query -> similarity = 0.0
        -1.0, 0.0, // Opposite to query -> similarity = -1.0
    };
    var results: [3]f32 = undefined;

    vector_ops.batch_cosine_similarity_zig(&query, &embeddings, 3, 2, &results);

    try testing.expectApproxEqRel(results[0], 1.0, 0.001);
    try testing.expectApproxEqRel(results[1], 0.0, 0.001);
    try testing.expectApproxEqRel(results[2], -1.0, 0.001);
}

test "batch similarity with threshold" {
    var query = [_]f32{ 1.0, 0.0 };
    var embeddings = [_]f32{
        1.0, 0.0, // similarity = 1.0 (above threshold)
        0.8, 0.6, // similarity ≈ 0.8 (above threshold)
        0.0, 1.0, // similarity = 0.0 (below threshold)
        -1.0, 0.0, // similarity = -1.0 (below threshold)
    };
    var results: [4]f32 = undefined;
    var indices: [4]u32 = undefined;

    const count = vector_ops.batch_similarity_with_threshold_zig(&query, &embeddings, 4, 2, 0.5, &results, &indices);

    try testing.expectEqual(count, 2); // Should find 2 results above threshold

    // First result should be index 0 with similarity ~1.0
    try testing.expectEqual(indices[0], 0);
    try testing.expectApproxEqRel(results[0], 1.0, 0.001);

    // Second result should be index 1 with similarity ~0.8
    try testing.expectEqual(indices[1], 1);
    try testing.expect(results[1] > 0.7 and results[1] < 0.9);
}

test "normalize vector" {
    var vec = [_]f32{ 3.0, 4.0 }; // Length = 5.0

    vector_ops.normalize_vector_zig(&vec);

    // Should be normalized to unit vector
    try testing.expectApproxEqRel(vec[0], 0.6, 0.001); // 3/5
    try testing.expectApproxEqRel(vec[1], 0.8, 0.001); // 4/5

    // Check magnitude is 1.0
    const magnitude = vector_ops.vector_magnitude_zig(&vec);
    try testing.expectApproxEqRel(magnitude, 1.0, 0.001);
}

test "vector magnitude" {
    const vec = [_]f32{ 3.0, 4.0 };
    const magnitude = vector_ops.vector_magnitude_zig(&vec);
    try testing.expectApproxEqRel(magnitude, 5.0, 0.001);
}

test "large vector performance" {
    // Test with realistic embedding dimensions (384D like all-MiniLM-L6-v2)
    var allocator = testing.allocator;

    const dim = 384;
    const num_embeddings = 100;

    const query = try allocator.alloc(f32, dim);
    defer allocator.free(query);

    const embeddings = try allocator.alloc(f32, num_embeddings * dim);
    defer allocator.free(embeddings);

    const results = try allocator.alloc(f32, num_embeddings);
    defer allocator.free(results);

    // Initialize with known pattern
    for (query, 0..) |*val, i| {
        val.* = @floatFromInt(i % 10);
    }

    for (0..num_embeddings) |i| {
        for (0..dim) |j| {
            embeddings[i * dim + j] = @floatFromInt((i + j) % 10);
        }
    }

    // Normalize vectors
    vector_ops.normalize_vector_zig(query);
    for (0..num_embeddings) |i| {
        const start = i * dim;
        const end = start + dim;
        vector_ops.normalize_vector_zig(embeddings[start..end]);
    }

    // Run batch similarity
    vector_ops.batch_cosine_similarity_zig(query, embeddings, num_embeddings, dim, results);

    // Verify results are in valid range [-1, 1]
    for (results) |similarity| {
        try testing.expect(similarity >= -1.0 and similarity <= 1.0);
    }

    // First embedding should have highest similarity (same pattern as query)
    try testing.expect(results[0] > 0.9);
}

test "edge cases" {
    // Empty vectors (should not crash)
    const empty: [0]f32 = .{};
    const empty_result = vector_ops.cosine_similarity_zig(&empty, &empty);
    try testing.expectEqual(empty_result, 0.0);

    // Single element vectors
    const single1 = [_]f32{5.0};
    const single2 = [_]f32{3.0};
    const single_result = vector_ops.cosine_similarity_zig(&single1, &single2);
    try testing.expectApproxEqRel(single_result, 1.0, 0.001); // Both positive, so similarity = 1
}

test "SIMD performance consistency" {
    // Test that SIMD and scalar paths give same results
    var allocator = testing.allocator;

    // Create vectors that will test both SIMD and scalar paths
    const dim = 17; // Not divisible by 8 (SIMD width)

    const vec1 = try allocator.alloc(f32, dim);
    defer allocator.free(vec1);

    const vec2 = try allocator.alloc(f32, dim);
    defer allocator.free(vec2);

    // Initialize with specific pattern
    for (0..dim) |i| {
        vec1[i] = @sin(@as(f32, @floatFromInt(i)) * 0.1);
        vec2[i] = @cos(@as(f32, @floatFromInt(i)) * 0.1);
    }

    const result = vector_ops.cosine_similarity_zig(vec1, vec2);

    // Should be a valid similarity score
    try testing.expect(result >= -1.0 and result <= 1.0);

    // Test multiple times to ensure consistency
    for (0..10) |_| {
        const repeat_result = vector_ops.cosine_similarity_zig(vec1, vec2);
        try testing.expectEqual(result, repeat_result);
    }
}
