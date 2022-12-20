const std = @import("std");

pub fn read_in(a: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return try file.readToEndAlloc(a, std.math.maxInt(usize));
}
