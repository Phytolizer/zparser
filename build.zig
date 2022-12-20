const std = @import("std");

const initial_pkg = std.build.Pkg{
    .name = "initial",
    .source = .{ .path = "src/initial/main.zig" },
};

fn printer(comptime msg: []const u8) fn (*std.build.Step) anyerror!void {
    return struct {
        fn f(_: *std.build.Step) anyerror!void {
            std.debug.print("{s}\n", .{msg});
        }
    }.f;
}

fn add_print_step(
    b: *std.build.Builder,
    comptime msg: []const u8,
    parent: *std.build.Step,
) void {
    const step = b.step("print", msg);
    step.makeFn = printer(msg);
    parent.dependOn(step);
}

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zparser", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addPackage(initial_pkg);
    exe.linkLibC();
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const initial_tests = b.addTest("src/initial/main.zig");
    initial_tests.setTarget(target);
    initial_tests.setBuildMode(mode);
    initial_tests.linkLibC();

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);
    exe_tests.linkLibC();
    exe_tests.addPackage(initial_pkg);

    const test_step = b.step("test", "Run unit tests");
    add_print_step(b, "[TEST] initial", test_step);
    test_step.dependOn(&initial_tests.step);
    add_print_step(b, "[TEST] exe", test_step);
    test_step.dependOn(&exe_tests.step);
}
