const std = @import("std");
const Line = @import("Line.zig");
const Lines = @import("Lines.zig");

/// Breaks a sequence of bytes into a list of lines.
///
/// This function takes in a sequence of bytes and breaks it into a list of
/// lines, where a line is defined as a sequence of bytes terminated by a
/// newline character (either `\n` or `\r\n`). The input bytes are processed
/// iteratively and the lines are appended to an output list.
///
/// Args:
/// - `a`: The allocator to use for creating the output list.
/// - `input`: The input sequence of bytes to be broken into lines.
///
/// Returns:
/// A list of lines contained in the input sequence.
pub fn breakLines(a: std.mem.Allocator, input: []u8) !Lines {
    var lines = std.ArrayList(Line).init(a);
    errdefer lines.deinit();

    // input iterator
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
            // no newline found, return the rest of the input
            break :blk EndLen{ .pos = input_it.len, .len = 0 };
        };
        // slice the line out of the input
        const line = input_it[0..end.pos];
        try lines.append(Line.initRef(line));
        // advance the input iterator
        input_it = input_it[end.pos + end.len ..];
    }

    return Lines.init(lines);
}

fn testInput(input: []const u8, expected: []const []const u8) !void {
    const dupe_input = try std.testing.allocator.dupe(u8, input);
    defer std.testing.allocator.free(dupe_input);
    const lines = try breakLines(std.testing.allocator, dupe_input);
    defer lines.deinit();
    try std.testing.expectEqual(expected.len, lines.inner.items.len);
    for (expected) |line, i| {
        try std.testing.expectEqualStrings(line, lines.inner.items[i].items);
    }
}

test "empty input" {
    const input = "";
    const expected = [_][]const u8{};
    try testInput(input, &expected);
}

test "consecutive breaks" {
    const input = "\n\n\n";
    const expected = [_][]const u8{ "", "", "" };
    try testInput(input, &expected);
}

test "one line" {
    const input = "hello";
    const expected = [_][]const u8{"hello"};
    try testInput(input, &expected);
}

test "mixed newline styles" {
    const input = "hello\r\nworld\nhow are you\rdoing?";
    const expected = [_][]const u8{ "hello", "world", "how are you\rdoing?" };
    try testInput(input, &expected);
}
