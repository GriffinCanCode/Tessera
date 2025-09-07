const std = @import("std");
const testing = std.testing;
const db_ops = @import("db_ops");

test "hash content - basic test" {
    const content = "Hello, World!";
    var result: [16]u8 = undefined;
    
    db_ops.hash_content(content.ptr, &result);
    
    // Should produce a consistent hash
    var result2: [16]u8 = undefined;
    db_ops.hash_content(content.ptr, &result2);
    
    try testing.expectEqualSlices(u8, &result, &result2);
    
    // Hash should be hex string
    for (result) |byte| {
        try testing.expect((byte >= '0' and byte <= '9') or (byte >= 'a' and byte <= 'f'));
    }
}

test "hash content - different inputs" {
    const content1 = "Hello, World!";
    const content2 = "Hello, World?";
    
    var result1: [16]u8 = undefined;
    var result2: [16]u8 = undefined;
    
    db_ops.hash_content(content1.ptr, &result1);
    db_ops.hash_content(content2.ptr, &result2);
    
    // Different inputs should produce different hashes
    try testing.expect(!std.mem.eql(u8, &result1, &result2));
}

test "hash content - empty string" {
    const content = "";
    var result: [16]u8 = undefined;
    
    db_ops.hash_content(content.ptr, &result);
    
    // Should handle empty string without crashing
    // Hash should still be valid hex
    for (result) |byte| {
        try testing.expect((byte >= '0' and byte <= '9') or (byte >= 'a' and byte <= 'f'));
    }
}

test "validate embedding blob - valid size" {
    // Create a mock embedding blob (100 floats = 400 bytes)
    var blob: [400]u8 = undefined;
    
    const is_valid = db_ops.validate_embedding_blob(&blob, 400);
    try testing.expect(is_valid);
}

test "validate embedding blob - invalid size" {
    // Create a blob that's not divisible by sizeof(f32)
    var blob: [399]u8 = undefined;
    
    const is_valid = db_ops.validate_embedding_blob(&blob, 399);
    try testing.expect(!is_valid);
}

test "validate embedding blob - null pointer" {
    const is_valid = db_ops.validate_embedding_blob(null, 400);
    try testing.expect(!is_valid);
}

test "validate embedding blob - zero size" {
    var blob: [1]u8 = undefined;
    
    const is_valid = db_ops.validate_embedding_blob(&blob, 0);
    try testing.expect(is_valid); // Zero size is valid (empty embedding)
}
