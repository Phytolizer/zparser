const std = @import("std");
const readIn = @import("initial").readIn;

pub const FileLike = struct {
    kind: Kind,
    contents: []const u8,
    deinit: *const fn (*@This()) void,

    pub const Kind = enum {
        /// A real file on the filesystem that must interact with the OS to be
        /// read.
        os,
        /// A fake file which simply contains the contents to be read.
        virtual,
    };
};

pub const OsFile = struct {
    base: FileLike,
    a: std.mem.Allocator,
    buf: []u8,

    pub fn init(self: *@This(), a: std.mem.Allocator, path: []const u8) !void {
        self.buf = try readIn(a, path);
        self.base = .{
            .kind = .os,
            .contents = self.buf,
            .deinit = deinit,
        };
        self.a = a;
    }

    pub fn create(a: std.mem.Allocator, path: []const u8) !*@This() {
        var result = try a.create(@This());
        try init(result, a, path);
        return result;
    }

    pub fn deinit(base: *FileLike) void {
        const self = @fieldParentPtr(@This(), "base", base);
        self.a.free(self.buf);
    }
};

pub const VirtualFile = struct {
    base: FileLike,

    pub fn create(contents: []const u8) @This() {
        return .{ .base = .{
            .kind = .virtual,
            .contents = contents,
            .deinit = deinit,
        } };
    }

    pub fn deinit(_: *FileLike) void {}
};
