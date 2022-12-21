const std = @import("std");
const Line = @import("Line.zig");
const Lines = @import("Lines.zig");

/// Tracks the state of comments in a sequence of lines.
const Comments = struct {
    /// Whether the current position is within a string literal.
    in_string: bool = false,
    /// Whether the current position is within a block comment.
    in_block_comment: bool = false,
    /// Whether the current position is within a line comment.
    in_line_comment: bool = false,
    /// The previous character that was processed.
    prev_char: u8 = 0,
};

/// Represents a character to be emitted.
const Emit = struct {
    /// The character to be emitted.
    ch: u8,
    /// The number of characters to remove from the emitted output before emitting `ch`.
    pop_count: usize = 0,
};

/// Determines whether a character should be emitted and, if so, yields the
/// modified character and updates the `Comments` struct as needed.
///
/// This function processes a single character and determines whether it should
/// be emitted or discarded based on the current state of the `Comments` struct.
/// It also updates the `Comments` struct as necessary based on the character
/// being processed, and yields the modified character (if it is to be emitted)
/// along with any necessary backtracking of previously emitted output.
///
/// Args:
/// - `ch`: The character to be processed.
/// - `comments`: A pointer to the `Comments` struct that tracks the state of
///               comments in the input.
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
        return .{ .ch = ' ', .pop_count = 1 };
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

/// Remove comments from the `lines` array.
///
/// This function processes each line of the input array in turn, and removes
/// any comments that it encounters. The resulting array will contain only the
/// non-comment parts of the original lines.
///
/// Args:
/// - `lines`: A pointer to an array of `Line` objects. The modified array is
///            returned via this argument.
pub fn delComments(lines: *Lines) !void {
    const a = lines.inner.allocator;

    // holds the current line, minus comments. lines may be merged
    var builder = std.ArrayList(u8).init(a);
    defer builder.deinit();

    // tracks comment state
    var comments = Comments{};

    // read/write indices
    var rd: usize = 0;
    var wr: usize = 0;

    while (rd < lines.inner.items.len) {
        const line = lines.inner.items[rd].items;
        for (line) |ch| {
            if (shouldEmit(ch, &comments)) |emit| {
                // backtrack if needed via pop_count
                const new_len = builder.items.len - emit.pop_count;
                builder.shrinkRetainingCapacity(new_len);
                try builder.append(emit.ch);
            }

            comments.prev_char = ch;
        }

        // terminate line comment
        if (shouldEmit('\n', &comments)) |emit| {
            const new_len = builder.items.len - emit.pop_count;
            builder.shrinkRetainingCapacity(new_len);
            try builder.append(emit.ch);
        }
        if (!comments.in_block_comment) {
            // copy the line to output
            lines.inner.items[wr].replace(
                try Line.initAlloc(a, try builder.toOwnedSlice()),
            );
            wr += 1;
        }

        rd += 1;
    }

    lines.shrink(wr);
}

fn testInput(input: []const u8, expected: []const []const u8) !void {
    const dupe_input = try std.testing.allocator.dupe(u8, input);
    var lines = try @import("break_lines.zig").breakLines(
        std.testing.allocator,
        dupe_input,
    );
    defer lines.deinit();
    try @import("merge_escaped_newlines.zig").mergeEscapedNewlines(&lines);
    try delComments(&lines);
    try std.testing.expectEqual(expected.len, lines.inner.items.len);
    for (expected) |line, i| {
        try std.testing.expectEqualSlices(u8, line, lines.inner.items[i].items);
    }
}

test "no comments" {
    const input = "foo bar baz";
    const expected = [_][]const u8{"foo bar baz"};
    try testInput(input, &expected);
}

test "line and block comments" {
    const input =
        \\#include <stdio.h> // this is a line comment
        \\
        \\int main() {
        \\  /* this is a
        \\     block comment */
        \\  printf("hi\n");
        \\}
    ;
    const expected = [_][]const u8{
        "#include <stdio.h>  ",
        "",
        "int main() {",
        "   ",
        "  printf(\"hi\\n\");",
        "}",
    };
    try testInput(input, &expected);
}

test "comment in string literal" {
    const input =
        \\#include <stdio.h>
        \\
        \\int main() {
        \\  printf("/* this is a comment */");
        \\}
    ;
    const expected = [_][]const u8{
        "#include <stdio.h>",
        "",
        "int main() {",
        "  printf(\"/* this is a comment */\");",
        "}",
    };
    try testInput(input, &expected);
}

test "escaped quotes in string literal" {
    const input =
        \\#include <stdio.h>
        \\
        \\int main() {
        \\  printf("foo \"bar\" baz");
        \\}
    ;
    const expected = [_][]const u8{
        "#include <stdio.h>",
        "",
        "int main() {",
        "  printf(\"foo \\\"bar\\\" baz\");",
        "}",
    };
    try testInput(input, &expected);
}

test "complex" {
    const input =
        \\/\
        \\*
        \\*/ # /*
        \\*/ defi\
        \\ne FO\
        \\O 10\
        \\20
    ;
    const expected = [_][]const u8{"  #   define FOO 1020"};
    try testInput(input, &expected);
}
