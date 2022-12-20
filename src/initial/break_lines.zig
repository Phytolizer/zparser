const std = @import("std");
const Line = @import("Line.zig");
const Lines = @import("Lines.zig");

pub fn break_lines(a: std.mem.Allocator, input: []u8) !Lines {
    var lines = std.ArrayList(Line).init(a);
    errdefer lines.deinit();

    var input_it = input;

    while (input_it.len > 0) {
        // find \r\n or \n, whichever comes first
        const EndLen = struct { pos: usize, len: usize };
        const end = blk: {
            if (std.mem.indexOf(u8, input_it, "\r\n")) |i| {
                break :blk EndLen{ .pos = i, .len = 2 };
            }
            if (std.mem.indexOfScalar(u8, input_it, '\n')) |i| {
                break :blk EndLen{ .pos = i, .len = 1 };
            }
            break :blk EndLen{ .pos = input_it.len, .len = 0 };
        };
        const line = input_it[0..end.pos];
        try lines.append(Line.initRef(line));
        input_it = input_it[end.pos + end.len ..];
    }

    return Lines.init(lines);
}

test "break lines" {
    const input = "hello\r\nworld\nfoo\rbar";
    const dupe_input = try std.testing.allocator.dupe(u8, input);
    defer std.testing.allocator.free(dupe_input);
    const lines = try break_lines(std.testing.allocator, dupe_input);
    defer lines.deinit();
    const expected = [_][]const u8{ "hello", "world", "foo\rbar" };
    try std.testing.expectEqual(expected.len, lines.inner.items.len);
    for (expected) |line, i| {
        try std.testing.expectEqualStrings(line, lines.inner.items[i].items);
    }
}
