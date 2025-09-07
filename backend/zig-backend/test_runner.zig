const std = @import("std");
const testing = std.testing;

// Import all test modules
const test_vector_ops = @import("src/test_vector_ops.zig");
const test_db_ops = @import("src/test_db_ops.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    std.debug.print("🧪 Running Tessera Zig Test Suite\n");
    std.debug.print("=================================\n\n");
    
    // Run vector operations tests
    std.debug.print("📊 Vector Operations Tests:\n");
    try runTestGroup("Vector Operations", test_vector_ops);
    
    // Run database operations tests  
    std.debug.print("\n💾 Database Operations Tests:\n");
    try runTestGroup("Database Operations", test_db_ops);
    
    std.debug.print("\n✅ All tests completed successfully!\n");
}

fn runTestGroup(comptime name: []const u8, comptime test_module: type) !void {
    const test_functions = comptime blk: {
        const module_info = @typeInfo(test_module);
        var functions: []const std.builtin.Type.Declaration = &.{};
        
        for (module_info.Struct.decls) |decl| {
            if (decl.is_pub and @hasDecl(test_module, decl.name)) {
                const func = @field(test_module, decl.name);
                if (@TypeOf(func) == fn () anyerror!void) {
                    functions = functions ++ [_]std.builtin.Type.Declaration{decl};
                }
            }
        }
        break :blk functions;
    };
    
    var passed: u32 = 0;
    var total: u32 = 0;
    
    inline for (test_functions) |decl| {
        const test_name = decl.name;
        const test_func = @field(test_module, test_name);
        
        total += 1;
        
        test_func() catch |err| {
            std.debug.print("  ❌ {s}: {}\n", .{ test_name, err });
            continue;
        };
        
        std.debug.print("  ✅ {s}\n", .{test_name});
        passed += 1;
    }
    
    std.debug.print("  📊 {s}: {}/{} tests passed\n", .{ name, passed, total });
    
    if (passed != total) {
        return error.TestsFailed;
    }
}
