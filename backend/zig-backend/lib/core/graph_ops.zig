const std = @import("std");
const math = std.math;
const testing = std.testing;
const builtin = @import("builtin");

// Graph-specific optimizations for R backend
const VERSION = "1.0.0";

// Export C-compatible functions for graph operations
export fn adjacency_matrix_multiply(
    matrix: [*]const f32,
    n: usize,
    result: [*]f32,
) callconv(.c) void {
    // Optimized matrix multiplication for adjacency matrices
    if (n == 0) return;

    // Initialize result matrix to zero
    for (0..n * n) |i| {
        result[i] = 0.0;
    }

    // Perform matrix multiplication with cache-friendly access pattern
    for (0..n) |i| {
        for (0..n) |k| {
            const a_ik = matrix[i * n + k];
            if (a_ik != 0.0) { // Skip zero multiplications
                for (0..n) |j| {
                    result[i * n + j] += a_ik * matrix[k * n + j];
                }
            }
        }
    }
}

export fn calculate_degree_centrality(
    adjacency: [*]const f32,
    n: usize,
    in_degree: [*]f32,
    out_degree: [*]f32,
    total_degree: [*]f32,
) callconv(.c) void {
    if (n == 0) return;

    // Initialize arrays
    for (0..n) |i| {
        in_degree[i] = 0.0;
        out_degree[i] = 0.0;
        total_degree[i] = 0.0;
    }

    // Calculate degrees efficiently
    for (0..n) |i| {
        for (0..n) |j| {
            const weight = adjacency[i * n + j];
            if (weight > 0.0) {
                out_degree[i] += weight;
                in_degree[j] += weight;
            }
        }
    }

    // Calculate total degree
    for (0..n) |i| {
        total_degree[i] = in_degree[i] + out_degree[i];
    }
}

export fn calculate_betweenness_centrality_fast(
    adjacency: [*]const f32,
    n: usize,
    betweenness: [*]f32,
) callconv(.c) void {
    if (n == 0) return;

    // Initialize betweenness to zero
    for (0..n) |i| {
        betweenness[i] = 0.0;
    }

    // For each source vertex
    for (0..n) |s| {
        // Stack for vertices in order of non-increasing distance from s
        var stack: [1000]usize = undefined; // Assume max 1000 nodes
        var stack_size: usize = 0;

        // Predecessors and distances
        var pred: [1000][100]usize = undefined; // Max 100 predecessors per node
        var pred_count: [1000]usize = undefined;
        var dist: [1000]f32 = undefined;
        var sigma: [1000]f32 = undefined;
        var delta: [1000]f32 = undefined;

        if (n > 1000) return; // Safety check

        // Initialize
        for (0..n) |i| {
            pred_count[i] = 0;
            dist[i] = -1.0;
            sigma[i] = 0.0;
            delta[i] = 0.0;
        }

        dist[s] = 0.0;
        sigma[s] = 1.0;

        // BFS-like traversal (simplified for dense graphs)
        var queue: [1000]usize = undefined;
        var queue_start: usize = 0;
        var queue_end: usize = 1;
        queue[0] = s;

        while (queue_start < queue_end and queue_end < 1000) {
            const v = queue[queue_start];
            queue_start += 1;
            stack[stack_size] = v;
            stack_size += 1;

            // For each neighbor w of v
            for (0..n) |w| {
                if (adjacency[v * n + w] > 0.0) {
                    // First time we find shortest path to w?
                    if (dist[w] < 0.0) {
                        queue[queue_end] = w;
                        queue_end += 1;
                        dist[w] = dist[v] + 1.0;
                    }

                    // Shortest path to w via v?
                    if (dist[w] == dist[v] + 1.0) {
                        sigma[w] += sigma[v];
                        if (pred_count[w] < 100) {
                            pred[w][pred_count[w]] = v;
                            pred_count[w] += 1;
                        }
                    }
                }
            }
        }

        // Accumulation - back propagation of dependencies
        while (stack_size > 0) {
            stack_size -= 1;
            const w = stack[stack_size];

            for (0..pred_count[w]) |i| {
                const v = pred[w][i];
                delta[v] += (sigma[v] / sigma[w]) * (1.0 + delta[w]);
            }

            if (w != s) {
                betweenness[w] += delta[w];
            }
        }
    }

    // Normalize for undirected graphs
    for (0..n) |i| {
        betweenness[i] /= 2.0;
    }
}

export fn calculate_pagerank_fast(
    adjacency: [*]const f32,
    n: usize,
    damping: f32,
    iterations: usize,
    pagerank: [*]f32,
) callconv(.c) void {
    if (n == 0) return;

    const d = damping;
    const base_value = (1.0 - d) / @as(f32, @floatFromInt(n));

    // Initialize PageRank values
    for (0..n) |i| {
        pagerank[i] = 1.0 / @as(f32, @floatFromInt(n));
    }

    // Calculate out-degrees for normalization
    var out_degree: [1000]f32 = undefined;
    if (n > 1000) return; // Safety check

    for (0..n) |i| {
        out_degree[i] = 0.0;
        for (0..n) |j| {
            out_degree[i] += adjacency[i * n + j];
        }
        if (out_degree[i] == 0.0) {
            out_degree[i] = 1.0; // Avoid division by zero
        }
    }

    // Power iteration
    for (0..iterations) |_| {
        var new_pagerank: [1000]f32 = undefined;

        // Initialize with base value
        for (0..n) |i| {
            new_pagerank[i] = base_value;
        }

        // Add contributions from incoming links
        for (0..n) |i| {
            const contribution = d * pagerank[i] / out_degree[i];
            for (0..n) |j| {
                if (adjacency[i * n + j] > 0.0) {
                    new_pagerank[j] += contribution * adjacency[i * n + j];
                }
            }
        }

        // Update PageRank values
        for (0..n) |i| {
            pagerank[i] = new_pagerank[i];
        }
    }
}

export fn calculate_clustering_coefficient(
    adjacency: [*]const f32,
    n: usize,
    clustering: [*]f32,
) callconv(.c) void {
    if (n == 0) return;

    for (0..n) |i| {
        var triangles: f32 = 0.0;
        var possible_triangles: f32 = 0.0;

        // Count neighbors
        var neighbors: [1000]usize = undefined;
        var neighbor_count: usize = 0;

        if (n > 1000) {
            clustering[i] = 0.0;
            continue;
        }

        for (0..n) |j| {
            if (i != j and adjacency[i * n + j] > 0.0) {
                neighbors[neighbor_count] = j;
                neighbor_count += 1;
            }
        }

        if (neighbor_count < 2) {
            clustering[i] = 0.0;
            continue;
        }

        // Count triangles
        for (0..neighbor_count) |j| {
            for (j + 1..neighbor_count) |k| {
                const neighbor_j = neighbors[j];
                const neighbor_k = neighbors[k];
                if (adjacency[neighbor_j * n + neighbor_k] > 0.0) {
                    triangles += 1.0;
                }
            }
        }

        possible_triangles = @as(f32, @floatFromInt(neighbor_count * (neighbor_count - 1))) / 2.0;
        clustering[i] = if (possible_triangles > 0.0) triangles / possible_triangles else 0.0;
    }
}

export fn optimize_layout_forces(
    positions: [*]f32, // x, y coordinates interleaved
    n: usize,
    adjacency: [*]const f32,
    k: f32, // Optimal distance
    iterations: usize,
) callconv(.c) void {
    if (n == 0) return;

    const dt: f32 = 0.1;

    for (0..iterations) |iter| {
        var forces: [2000]f32 = undefined; // Max 1000 nodes * 2 coordinates
        if (n * 2 > 2000) return; // Safety check

        // Initialize forces to zero
        for (0..n * 2) |i| {
            forces[i] = 0.0;
        }

        // Calculate repulsive forces
        for (0..n) |i| {
            for (i + 1..n) |j| {
                const dx = positions[i * 2] - positions[j * 2];
                const dy = positions[i * 2 + 1] - positions[j * 2 + 1];
                const dist = math.sqrt(dx * dx + dy * dy);

                if (dist > 0.0) {
                    const force_magnitude = k * k / dist;
                    const fx = force_magnitude * dx / dist;
                    const fy = force_magnitude * dy / dist;

                    forces[i * 2] += fx;
                    forces[i * 2 + 1] += fy;
                    forces[j * 2] -= fx;
                    forces[j * 2 + 1] -= fy;
                }
            }
        }

        // Calculate attractive forces for connected nodes
        for (0..n) |i| {
            for (0..n) |j| {
                if (i != j and adjacency[i * n + j] > 0.0) {
                    const dx = positions[j * 2] - positions[i * 2];
                    const dy = positions[j * 2 + 1] - positions[i * 2 + 1];
                    const dist = math.sqrt(dx * dx + dy * dy);

                    if (dist > 0.0) {
                        const force_magnitude = dist * dist / k * adjacency[i * n + j];
                        const fx = force_magnitude * dx / dist;
                        const fy = force_magnitude * dy / dist;

                        forces[i * 2] += fx;
                        forces[i * 2 + 1] += fy;
                    }
                }
            }
        }

        // Update positions with damping
        const damping = 1.0 - @as(f32, @floatFromInt(iter)) / @as(f32, @floatFromInt(iterations)) * 0.9;
        for (0..n) |i| {
            positions[i * 2] += dt * forces[i * 2] * damping;
            positions[i * 2 + 1] += dt * forces[i * 2 + 1] * damping;
        }
    }
}

// Utility function to check if graph operations are available
export fn tessera_graph_ops_version() callconv(.c) [*:0]const u8 {
    return VERSION.ptr;
}

// Tests
test "degree centrality calculation" {
    // Simple 3-node graph: 0->1, 1->2, 2->0
    var adjacency = [_]f32{
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
        1.0, 0.0, 0.0,
    };

    var in_degree: [3]f32 = undefined;
    var out_degree: [3]f32 = undefined;
    var total_degree: [3]f32 = undefined;

    calculate_degree_centrality(&adjacency, 3, &in_degree, &out_degree, &total_degree);

    // Each node should have in-degree = 1, out-degree = 1, total = 2
    for (0..3) |i| {
        try testing.expectApproxEqRel(in_degree[i], 1.0, 0.001);
        try testing.expectApproxEqRel(out_degree[i], 1.0, 0.001);
        try testing.expectApproxEqRel(total_degree[i], 2.0, 0.001);
    }
}

test "PageRank calculation" {
    // Simple 3-node graph
    var adjacency = [_]f32{
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
        1.0, 0.0, 0.0,
    };

    var pagerank: [3]f32 = undefined;
    calculate_pagerank_fast(&adjacency, 3, 0.85, 50, &pagerank);

    // PageRank values should sum to approximately 1.0
    const sum = pagerank[0] + pagerank[1] + pagerank[2];
    try testing.expectApproxEqRel(sum, 1.0, 0.01);

    // For a symmetric cycle, all nodes should have equal PageRank
    try testing.expectApproxEqRel(pagerank[0], pagerank[1], 0.01);
    try testing.expectApproxEqRel(pagerank[1], pagerank[2], 0.01);
}
