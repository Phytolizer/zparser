const std = @import("std");
const Lines = @import("Lines.zig");

pub fn unlines(a: std.mem.Allocator, lines: Lines) ![]u8 {
    var buf = std.ArrayList(u8).init(a);
    defer buf.deinit();
    for (lines.inner.items) |line| {
        try buf.appendSlice(line.items);
    }
    lines.deinit();
    return try buf.toOwnedSlice();
}
