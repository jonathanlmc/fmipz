const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const fmipz_mod = b.addModule("fmipz", .{
        .root_source_file = b.path("fmipz/src/fmipz.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mecha_ext_mod = b.addModule("mecha_ext", .{
        .root_source_file = b.path("mecha_ext/src/mecha_ext.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mecha = b.dependency("mecha", .{});

    fmipz_mod.addImport("mecha", mecha.module("mecha"));
    fmipz_mod.addImport("mecha_ext", mecha_ext_mod);

    mecha_ext_mod.addImport("mecha", mecha.module("mecha"));

    const test_step = b.step("test", "Run all tests.");

    const fmipz_tests = b.addTest(.{ .root_module = fmipz_mod });
    const mecha_ext_tests = b.addTest(.{ .root_module = mecha_ext_mod });

    const run_fmipz_tests = b.addRunArtifact(fmipz_tests);
    const run_mecha_ext_tests = b.addRunArtifact(mecha_ext_tests);

    if (b.args) |args| {
        run_fmipz_tests.addArgs(args);
        run_mecha_ext_tests.addArgs(args);
    }

    test_step.dependOn(&run_fmipz_tests.step);
    test_step.dependOn(&run_mecha_ext_tests.step);
}
