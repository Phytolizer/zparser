const std = @import("std");

const initial_pkg = std.build.Pkg{
    .name = "initial",
    .source = .{ .path = "src/initial/main.zig" },
};

const preprocessor_pkg = std.build.Pkg{
    .name = "preprocessor",
    .source = .{ .path = "src/preprocessor/main.zig" },
    .dependencies = &.{initial_pkg},
};

const pkgs = [_]std.build.Pkg{
    initial_pkg,
    preprocessor_pkg,
};

fn PrintStep(comptime fmt: []const u8, comptime Args: type) type {
    return struct {
        step: std.build.Step,
        args: Args,

        const Self = @This();

        pub fn init(a: std.mem.Allocator, args: Args) !*Self {
            const result = try a.create(Self);
            result.* = Self{
                .step = std.build.Step.init(.custom, "print", a, run),
                .args = args,
            };
            return result;
        }

        pub fn run(step_in: *std.build.Step) anyerror!void {
            const self = @fieldParentPtr(Self, "step", step_in);
            std.debug.print(fmt ++ "\n", self.args);
        }
    };
}

fn add_print_step(
    b: *std.build.Builder,
    parent: *std.build.Step,
    comptime msg: []const u8,
    args: anytype,
) !void {
    const ps = try PrintStep(msg, @TypeOf(args)).init(b.allocator, args);
    parent.dependOn(&ps.step);
}

pub fn build(b: *std.build.Builder) !void {
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

    const test_step = b.step("test", "Run unit tests");

    for (pkgs) |pkg| {
        const path = try std.fmt.allocPrint(
            b.allocator,
            "src/{s}/main.zig",
            .{pkg.name},
        );
        const tests = b.addTest(path);
        tests.setTarget(target);
        tests.setBuildMode(mode);
        tests.linkLibC();
        if (pkg.dependencies) |deps| for (deps) |dep| {
            tests.addPackage(dep);
        };
        try add_print_step(b, test_step, "[TEST] {s}", .{pkg.name});
        test_step.dependOn(&tests.step);
    }
}
