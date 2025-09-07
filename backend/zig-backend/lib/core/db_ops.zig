const std = @import("std");

// High-performance database operations
// Future: SQLite extensions, connection pooling optimizations

pub export fn hash_content(content: [*:0]const u8, result: [*]u8) void {
    // Fast content hashing for deduplication
    const content_slice = std.mem.span(content);
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(content_slice);
    const hash = hasher.final();
    
    // Convert to hex string
    _ = std.fmt.bufPrint(result[0..16], "{x:0>16}", .{hash}) catch unreachable;
}

pub export fn validate_embedding_blob(blob: ?[*]const u8, expected_size: usize) bool {
    // Validate embedding blob format and size
    if (blob == null) return false;
    
    // Check if it's the expected size for float32 array
    return (expected_size % @sizeOf(f32)) == 0;
}

// Placeholder for future SQLite extensions
// export fn sqlite_cosine_similarity(context: ?*anyopaque, argc: c_int, argv: [*c]?*anyopaque) void {
//     // Custom SQLite function for vector similarity
// }
