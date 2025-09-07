const std = @import("std");
const math = std.math;
const testing = std.testing;
const builtin = @import("builtin");

// Version information
const VERSION = "1.0.0";

// Export C-compatible functions for FFI with proper calling convention
// R-compatible version that takes result as pointer parameter
export fn cosine_similarity(vec1: [*]const f32, vec2: [*]const f32, len: [*]const usize, result: [*]f32) callconv(.c) void {
    const actual_len = len[0];
    if (actual_len == 0) {
        result[0] = 0.0;
        return;
    }
    result[0] = cosineSimilaritySimd(vec1[0..actual_len], vec2[0..actual_len]);
}

// Direct version for other uses
export fn cosine_similarity_direct(vec1: [*]const f32, vec2: [*]const f32, len: usize) callconv(.c) f32 {
    if (len == 0) return 0.0;
    return cosineSimilaritySimd(vec1[0..len], vec2[0..len]);
}

export fn batch_cosine_similarity(
    query: [*]const f32,
    embeddings: [*]const f32,
    num_embeddings: [*]const usize,
    vector_dim: [*]const usize,
    results: [*]f32,
) callconv(.c) void {
    const actual_num_embeddings = num_embeddings[0];
    const actual_vector_dim = vector_dim[0];

    if (actual_num_embeddings == 0 or actual_vector_dim == 0) return;

    const query_slice = query[0..actual_vector_dim];

    for (0..actual_num_embeddings) |i| {
        const embedding_start = i * actual_vector_dim;
        const embedding_slice = embeddings[embedding_start .. embedding_start + actual_vector_dim];
        results[i] = cosineSimilaritySimd(query_slice, embedding_slice);
    }
}

export fn batch_similarity_with_threshold(
    query: [*]const f32,
    embeddings: [*]const f32,
    num_embeddings: [*]const usize,
    vector_dim: [*]const usize,
    threshold: [*]const f32,
    results: [*]f32,
    indices: [*]u32,
    count_out: [*]usize,
) callconv(.c) void {
    const actual_num_embeddings = num_embeddings[0];
    const actual_vector_dim = vector_dim[0];
    const actual_threshold = threshold[0];

    if (actual_num_embeddings == 0 or actual_vector_dim == 0) {
        count_out[0] = 0;
        return;
    }

    const query_slice = query[0..actual_vector_dim];
    var count: usize = 0;

    for (0..actual_num_embeddings) |i| {
        const embedding_start = i * actual_vector_dim;
        const embedding_slice = embeddings[embedding_start .. embedding_start + actual_vector_dim];
        const similarity = cosineSimilaritySimd(query_slice, embedding_slice);

        if (similarity >= actual_threshold) {
            results[count] = similarity;
            indices[count] = @intCast(i);
            count += 1;
        }
    }

    count_out[0] = count;
}

// Internal SIMD-optimized cosine similarity
fn cosineSimilaritySimd(vec1: []const f32, vec2: []const f32) f32 {
    if (vec1.len != vec2.len) return 0.0;
    if (vec1.len == 0) return 0.0;

    // Use SIMD for better performance
    const simd_width = 8;
    const Vec8f = @Vector(simd_width, f32);

    var dot_product: f32 = 0.0;
    var norm1: f32 = 0.0;
    var norm2: f32 = 0.0;

    var i: usize = 0;

    // Process SIMD chunks
    while (i + simd_width <= vec1.len) : (i += simd_width) {
        const v1: Vec8f = vec1[i .. i + simd_width][0..simd_width].*;
        const v2: Vec8f = vec2[i .. i + simd_width][0..simd_width].*;

        dot_product += @reduce(.Add, v1 * v2);
        norm1 += @reduce(.Add, v1 * v1);
        norm2 += @reduce(.Add, v2 * v2);
    }

    // Handle remaining elements
    while (i < vec1.len) : (i += 1) {
        const a = vec1[i];
        const b = vec2[i];
        dot_product += a * b;
        norm1 += a * a;
        norm2 += b * b;
    }

    const magnitude = math.sqrt(norm1) * math.sqrt(norm2);
    if (magnitude > 0.0) {
        const similarity = dot_product / magnitude;
        // Clamp to [-1, 1] to handle floating-point precision errors
        return math.clamp(similarity, -1.0, 1.0);
    } else {
        return 0.0;
    }
}

// Utility functions
export fn normalize_vector(vec: [*]f32, len: [*]const usize) callconv(.c) void {
    const actual_len = len[0];
    if (actual_len == 0) return;

    const slice = vec[0..actual_len];
    var norm: f32 = 0.0;

    for (slice) |val| {
        norm += val * val;
    }

    norm = math.sqrt(norm);
    if (norm > 0.0) {
        for (slice) |*val| {
            val.* /= norm;
        }
    }
}

export fn vector_magnitude(vec: [*]const f32, len: [*]const usize, result: [*]f32) callconv(.c) void {
    const actual_len = len[0];
    if (actual_len == 0) {
        result[0] = 0.0;
        return;
    }

    const slice = vec[0..actual_len];
    var sum: f32 = 0.0;

    for (slice) |val| {
        sum += val * val;
    }

    result[0] = math.sqrt(sum);
}

// Additional utility functions for R compatibility
export fn tessera_vector_ops_version() callconv(.c) [*:0]const u8 {
    return VERSION.ptr;
}

export fn tessera_has_simd() callconv(.c) c_int {
    // Check for SIMD support based on target architecture
    return switch (builtin.cpu.arch) {
        .aarch64 => 1, // ARM64 has NEON
        .x86_64 => 1, // x86_64 has at least SSE2
        else => 0,
    };
}

// Public wrapper functions for internal Zig usage
pub fn cosine_similarity_zig(vec1: []const f32, vec2: []const f32) f32 {
    return cosineSimilaritySimd(vec1, vec2);
}

pub fn batch_cosine_similarity_zig(
    query: []const f32,
    embeddings: []const f32,
    num_embeddings: usize,
    vector_dim: usize,
    results: []f32,
) void {
    if (num_embeddings == 0 or vector_dim == 0) return;

    const query_slice = query[0..vector_dim];

    for (0..num_embeddings) |i| {
        const embedding_start = i * vector_dim;
        const embedding_slice = embeddings[embedding_start .. embedding_start + vector_dim];
        results[i] = cosineSimilaritySimd(query_slice, embedding_slice);
    }
}

pub fn batch_similarity_with_threshold_zig(
    query: []const f32,
    embeddings: []const f32,
    num_embeddings: usize,
    vector_dim: usize,
    threshold: f32,
    results: []f32,
    indices: []u32,
) usize {
    if (num_embeddings == 0 or vector_dim == 0) return 0;

    const query_slice = query[0..vector_dim];
    var count: usize = 0;

    for (0..num_embeddings) |i| {
        const embedding_start = i * vector_dim;
        const embedding_slice = embeddings[embedding_start .. embedding_start + vector_dim];
        const similarity = cosineSimilaritySimd(query_slice, embedding_slice);

        if (similarity >= threshold) {
            results[count] = similarity;
            indices[count] = @intCast(i);
            count += 1;
        }
    }

    return count;
}

pub fn normalize_vector_zig(vec: []f32) void {
    if (vec.len == 0) return;

    var norm: f32 = 0.0;

    for (vec) |val| {
        norm += val * val;
    }

    norm = math.sqrt(norm);
    if (norm > 0.0) {
        for (vec) |*val| {
            val.* /= norm;
        }
    }
}

pub fn vector_magnitude_zig(vec: []const f32) f32 {
    if (vec.len == 0) return 0.0;

    var sum: f32 = 0.0;

    for (vec) |val| {
        sum += val * val;
    }

    return math.sqrt(sum);
}

// Tests
test "cosine similarity basic" {
    const vec1 = [_]f32{ 1.0, 0.0, 0.0 };
    const vec2 = [_]f32{ 1.0, 0.0, 0.0 };
    const result = cosineSimilaritySimd(&vec1, &vec2);
    try testing.expectApproxEqRel(result, 1.0, 0.001);
}

test "cosine similarity orthogonal" {
    const vec1 = [_]f32{ 1.0, 0.0 };
    const vec2 = [_]f32{ 0.0, 1.0 };
    const result = cosineSimilaritySimd(&vec1, &vec2);
    try testing.expectApproxEqRel(result, 0.0, 0.001);
}

test "batch cosine similarity" {
    var query = [_]f32{ 1.0, 0.0 };
    var embeddings = [_]f32{
        1.0, 0.0, // Same as query
        0.0, 1.0, // Orthogonal to query
        -1.0, 0.0, // Opposite to query
    };
    var results: [3]f32 = undefined;

    batch_cosine_similarity(&query, &embeddings, 3, 2, &results);

    try testing.expectApproxEqRel(results[0], 1.0, 0.001);
    try testing.expectApproxEqRel(results[1], 0.0, 0.001);
    try testing.expectApproxEqRel(results[2], -1.0, 0.001);
}
