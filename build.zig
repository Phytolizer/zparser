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

fn collectAllSrc(a: std.mem.Allocator) ![][]u8 {
    var srcs = std.ArrayList([]u8).init(a);
    var dir = try std.fs.cwd().openIterableDir(".", .{});
    defer dir.close();
    var walker = try dir.walk(a);
    while (try walker.next()) |current| {
        if (current.kind != .File or
            !std.mem.endsWith(u8, current.path, ".zig") or
            std.mem.indexOf(u8, current.path, "zig-cache") != null)
        {
            continue;
        }

        try srcs.append(try a.dupe(u8, current.path));
    }

    return try srcs.toOwnedSlice();
}

const CheckLineLengthsStep = struct {
    step: std.build.Step,
    a: std.mem.Allocator,

    const max_line_len = 80;

    const Self = @This();

    pub fn init(a: std.mem.Allocator) !*Self {
        const result = try a.create(Self);
        result.* = .{
            .step = std.build.Step.init(.custom, "check-line-lengths", a, run),
            .a = a,
        };
        return result;
    }

    pub fn run(step_in: *std.build.Step) anyerror!void {
        const self = @fieldParentPtr(Self, "step", step_in);

        const srcs = try collectAllSrc(self.a);
        for (srcs) |current| {
            var file = try std.fs.cwd().openFile(current, .{});
            defer file.close();
            const reader = file.reader();
            var line = try std.ArrayList(u8).initCapacity(self.a, 80);
            var line_num: usize = 1;
            while (true) : (line_num += 1) {
                reader.readUntilDelimiterArrayList(
                    &line,
                    '\n',
                    std.math.maxInt(usize),
                ) catch |e| switch (e) {
                    error.EndOfStream => break,
                    else => return e,
                };

                if (line.items.len > max_line_len) {
                    std.debug.print("{s}:{d}: line is too long\n{s}", .{
                        current,
                        line_num,
                        line.items[0..max_line_len],
                    });
                    std.debug.print(
                        "\x1b[31m{s}\x1b[0m\n",
                        .{line.items[max_line_len..]},
                    );
                    std.debug.print(" " ** max_line_len ++ "^\n", .{});
                }
            }
        }
    }
};

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
    exe.addPackage(preprocessor_pkg);
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

    const check_line_lengths_step = b.step(
        "check-line-lengths",
        "Check line lengths of source",
    );
    const actual_check_line_lengths_step =
        try CheckLineLengthsStep.init(b.allocator);
    check_line_lengths_step.dependOn(&actual_check_line_lengths_step.step);

    const srcs = try collectAllSrc(b.allocator);
    const fmt_all = b.addFmt(srcs);
    const fmt_step = b.step("fmt", "Format all sources");
    fmt_step.dependOn(&fmt_all.step);
}
