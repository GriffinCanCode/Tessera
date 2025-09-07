const std = @import("std");
const vector_ops = @import("vector_ops.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🚀 Tessera Zig Performance Benchmark\n", .{});
    std.debug.print("=====================================\n\n", .{});

    // Test parameters matching your embedding dimensions
    const vector_dim = 384; // all-MiniLM-L6-v2 dimension
    const num_embeddings = 1000;
    
    // Allocate test data
    const query = try allocator.alloc(f32, vector_dim);
    defer allocator.free(query);
    
    const embeddings = try allocator.alloc(f32, num_embeddings * vector_dim);
    defer allocator.free(embeddings);
    
    const results = try allocator.alloc(f32, num_embeddings);
    defer allocator.free(results);
    
    // Initialize with random data
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    
    for (query) |*val| {
        val.* = random.floatNorm(f32);
    }
    
    for (embeddings) |*val| {
        val.* = random.floatNorm(f32);
    }
    
    // Normalize vectors (important for cosine similarity)
    vector_ops.normalize_vector(query.ptr, vector_dim);
    for (0..num_embeddings) |i| {
        const start = i * vector_dim;
        vector_ops.normalize_vector(embeddings.ptr + start, vector_dim);
    }
    
    // Benchmark batch cosine similarity
    const iterations = 100;
    var timer = try std.time.Timer.start();
    
    for (0..iterations) |_| {
        vector_ops.batch_cosine_similarity(
            query.ptr,
            embeddings.ptr,
            num_embeddings,
            vector_dim,
            results.ptr
        );
    }
    
    const elapsed_ns = timer.read();
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const avg_ms = elapsed_ms / iterations;
    
    std.debug.print("📊 Batch Cosine Similarity Results:\n", .{});
    std.debug.print("   Vector dimension: {}\n", .{vector_dim});
    std.debug.print("   Number of embeddings: {}\n", .{num_embeddings});
    std.debug.print("   Iterations: {}\n", .{iterations});
    std.debug.print("   Total time: {d:.2} ms\n", .{elapsed_ms});
    std.debug.print("   Average per batch: {d:.2} ms\n", .{avg_ms});
    std.debug.print("   Throughput: {d:.0} similarities/second\n", .{@as(f64, @floatFromInt(num_embeddings)) / (avg_ms / 1000.0)});
    
    // Show some sample results
    std.debug.print("\n📋 Sample similarities:\n", .{});
    for (results[0..@min(5, results.len)], 0..) |sim, i| {
        std.debug.print("   Embedding {}: {d:.4}\n", .{ i, sim });
    }
    
    // Benchmark with threshold filtering
    timer.reset();
    const threshold: f32 = 0.1;
    const filtered_results = try allocator.alloc(f32, num_embeddings);
    defer allocator.free(filtered_results);
    const filtered_indices = try allocator.alloc(u32, num_embeddings);
    defer allocator.free(filtered_indices);
    
    var total_filtered: u32 = 0;
    for (0..iterations) |_| {
        total_filtered = vector_ops.batch_similarity_with_threshold(
            query.ptr,
            embeddings.ptr,
            num_embeddings,
            vector_dim,
            threshold,
            filtered_results.ptr,
            filtered_indices.ptr
        );
    }
    
    const filtered_elapsed_ns = timer.read();
    const filtered_elapsed_ms = @as(f64, @floatFromInt(filtered_elapsed_ns)) / 1_000_000.0;
    const filtered_avg_ms = filtered_elapsed_ms / iterations;
    
    std.debug.print("\n🎯 Threshold Filtering Results (threshold = {d:.2}):\n", .{threshold});
    std.debug.print("   Average time: {d:.2} ms\n", .{filtered_avg_ms});
    std.debug.print("   Results above threshold: {}/{}\n", .{ total_filtered, num_embeddings });
    std.debug.print("   Filtering efficiency: {d:.1}%\n", .{(@as(f64, @floatFromInt(total_filtered)) / @as(f64, @floatFromInt(num_embeddings))) * 100.0});
    
    std.debug.print("\n✅ Benchmark complete!\n", .{});
}
