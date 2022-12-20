const std = @import("std");
const Lines = @import("Lines.zig");

pub fn unlines(lines: Lines) ![]u8 {
    var buf = std.ArrayList(u8).init(lines.inner.allocator);
    defer buf.deinit();
    for (lines.inner.items) |line| {
        try buf.appendSlice(line.items);
    }
    lines.deinit();
    return try buf.toOwnedSlice();
}
