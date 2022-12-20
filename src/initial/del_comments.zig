const std = @import("std");
const Line = @import("Line.zig");
const Lines = @import("Lines.zig");

const Comments = struct {
    in_string: bool = false,
    in_block_comment: bool = false,
    in_line_comment: bool = false,
    prev_char: u8 = 0,
};

const Emit = struct {
    ch: u8,
    pop_count: usize = 0,
};

fn shouldEmit(ch: u8, comments: *Comments) ?Emit {
    // string literals override all other rules
    if (comments.in_string) {
        if (ch == '"' and comments.prev_char != '\\') {
            // end of string literal
            comments.in_string = false;
        }
        return .{ .ch = ch };
    }

    if (comments.in_block_comment and ch == '/' and comments.prev_char == '*') {
        // end of block comment
        comments.in_block_comment = false;
        return .{ .ch = ' ', .pop_count = 1 };
    }
    if (comments.in_line_comment and ch == '\n') {
        // end of line comment
        comments.in_line_comment = false;
        return .{ .ch = ' ' };
    }
    if (comments.in_line_comment or comments.in_block_comment) {
        // still in comment...
        return null;
    }

    // check for start of comment
    switch (ch) {
        '/' => {
            if (comments.prev_char == '/') {
                // start of line comment
                comments.in_line_comment = true;
                return null;
            }
        },
        '*' => {
            if (comments.prev_char == '/') {
                // start of block comment
                comments.in_block_comment = true;
                return null;
            }
        },
        '"' => {
            // start of string literal
            comments.in_string = !comments.in_string;
            return .{ .ch = ch };
        },
        '\n' => {
            // newline just marks end of line, isn't really in input
            return null;
        },
        else => {},
    }
    // something else
    return .{ .ch = ch };
}

pub fn del_comments(lines: *Lines) !void {
    const a = lines.inner.allocator;
    var builder = std.ArrayList(u8).init(a);
    defer builder.deinit();
    var comments = Comments{};
    var rd: usize = 0;
    var wr: usize = 0;
    while (rd < lines.inner.items.len) : (rd += 1) {
        const line = lines.inner.items[rd].items;
        for (line) |ch| {
            if (shouldEmit(ch, &comments)) |emit| {
                const new_len = builder.items.len - emit.pop_count;
                builder.shrinkRetainingCapacity(new_len);
                try builder.append(emit.ch);
            }

            comments.prev_char = ch;
        }

        if (shouldEmit('\n', &comments)) |emit| {
            const new_len = builder.items.len - emit.pop_count;
            builder.shrinkRetainingCapacity(new_len);
            try builder.append(emit.ch);
        }
        if (!comments.in_block_comment) {
            // copy the line to output
            lines.inner.items[wr].replace(
                Line.initAlloc(a, try builder.toOwnedSlice()),
            );
            wr += 1;
        }
    }

    lines.shrink(wr);
}

test "escaped comments" {
    const input = @embedFile("tests/escaped_comments.c");
    const dupe_input = try std.testing.allocator.dupe(u8, input);
    defer std.testing.allocator.free(dupe_input);
    var lines = try @import("break_lines.zig").break_lines(
        std.testing.allocator,
        dupe_input,
    );
    defer lines.deinit();
    try @import("merge_escaped_newlines.zig").merge_escaped_newlines(&lines);
    try @import("del_comments.zig").del_comments(&lines);
    const expected = [_][]const u8{"  #   define FOO 1020"};
    try std.testing.expectEqual(expected.len, lines.inner.items.len);
    for (expected) |line, i| {
        try std.testing.expectEqualStrings(line, lines.inner.items[i].items);
    }
}
