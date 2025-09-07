const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Force release optimization for shared libraries
    const lib_optimize = if (optimize == .Debug) .ReleaseFast else optimize;

    // Vector operations shared library for R FFI
    const vector_shared_lib = b.addLibrary(.{
        .name = "tessera_vector_ops",
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib/core/vector_ops.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
    });

    // Enable C ABI for FFI compatibility
    vector_shared_lib.linkLibC();

    // Set proper shared library options for R compatibility
    if (target.result.os.tag == .macos) {
        vector_shared_lib.linker_allow_shlib_undefined = true;
    }

    // Install the shared library
    b.installArtifact(vector_shared_lib);

    // Create a C-based shared library specifically for R compatibility
    const vector_r_lib = b.addLibrary(.{
        .name = "tessera_vector_ops_r",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = lib_optimize,
        }),
        .linkage = .dynamic,
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
    });

    vector_r_lib.linkLibC();
    // Add optimized C source with SIMD flags
    const c_flags = switch (target.result.cpu.arch) {
        .aarch64 => &[_][]const u8{ "-O3", "-ffast-math", "-march=armv8-a+simd" },
        .x86_64 => &[_][]const u8{ "-O3", "-ffast-math", "-mavx2", "-mfma" },
        else => &[_][]const u8{ "-O3", "-ffast-math" },
    };
    vector_r_lib.addCSourceFile(.{ .file = b.path("lib/ffi/c_wrapper_r.c"), .flags = c_flags });
    if (target.result.os.tag == .macos) {
        vector_r_lib.linker_allow_shlib_undefined = true;
    }
    b.installArtifact(vector_r_lib);

    // Graph operations shared library for R FFI
    const graph_shared_lib = b.addLibrary(.{
        .name = "tessera_graph_ops",
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib/core/graph_ops.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
    });

    // Enable C ABI for FFI compatibility
    graph_shared_lib.linkLibC();

    // Set proper shared library options for R compatibility
    if (target.result.os.tag == .macos) {
        graph_shared_lib.linker_allow_shlib_undefined = true;
    }

    // Install the graph operations library
    b.installArtifact(graph_shared_lib);

    // Also create static library for other uses
    const vector_static_lib = b.addLibrary(.{
        .name = "tessera_vector_ops_static",
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib/core/vector_ops.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    vector_static_lib.linkLibC();
    b.installArtifact(vector_static_lib);

    // Database operations shared library for R FFI
    const db_shared_lib = b.addLibrary(.{
        .name = "tessera_db_ops",
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib/core/db_ops.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
    });

    db_shared_lib.linkLibC();
    if (target.result.os.tag == .macos) {
        db_shared_lib.linker_allow_shlib_undefined = true;
    }
    b.installArtifact(db_shared_lib);

    // Also create static library
    const db_static_lib = b.addLibrary(.{
        .name = "tessera_db_ops_static",
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib/core/db_ops.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    db_static_lib.linkLibC();
    b.installArtifact(db_static_lib);

    // Core modules for testing
    const vector_ops_module = b.createModule(.{
        .root_source_file = b.path("lib/core/vector_ops.zig"),
        .target = target,
        .optimize = optimize,
    });

    const db_ops_module = b.createModule(.{
        .root_source_file = b.path("lib/core/db_ops.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Tests
    const vector_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib/tests/test_vector_ops.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vector_ops", .module = vector_ops_module },
            },
        }),
    });

    const db_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib/tests/test_db_ops.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "db_ops", .module = db_ops_module },
            },
        }),
    });

    const test_step = b.step("test", "Run all library tests");
    test_step.dependOn(&b.addRunArtifact(vector_tests).step);
    test_step.dependOn(&b.addRunArtifact(db_tests).step);

    // Quick test executable
    const quick_test = b.addExecutable(.{
        .name = "quick_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("quick_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(quick_test);

    const quick_test_step = b.step("quick-test", "Run quick functionality test");
    quick_test_step.dependOn(&b.addRunArtifact(quick_test).step);

    // Benchmark executable
    const benchmark = b.addExecutable(.{
        .name = "benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib/core/benchmark.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    benchmark.linkLibC();
    b.installArtifact(benchmark);

    const benchmark_step = b.step("benchmark", "Run performance benchmarks");
    benchmark_step.dependOn(&b.addRunArtifact(benchmark).step);
}
