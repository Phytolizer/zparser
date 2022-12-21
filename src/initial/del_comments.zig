const std = @import("std");
const Line = @import("Line.zig");
const Lines = @import("Lines.zig");
const Builders = @import("Builders.zig");

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
        return null;
    }
    if (comments.in_line_comment and ch == '\n') {
        // end of line comment
        comments.in_line_comment = false;
        return .{ .ch = ch };
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
                return .{ .ch = ' ', .pop_count = 2 };
            }
        },
        '*' => {
            if (comments.prev_char == '/') {
                // start of block comment
                comments.in_block_comment = true;
                return .{ .ch = ' ', .pop_count = 2 };
            }
        },
        '"' => {
            // start of string literal
            comments.in_string = !comments.in_string;
            return .{ .ch = ch };
        },
        else => {},
    }
    // something else
    return .{ .ch = ch };
}

fn backtrack(builder: *Builders, pop_count: usize) void {
    var popped: usize = 0;
    var i: usize = builder.text.items.len;
    while (popped < pop_count) {
        while (i > 0 and builder.trivial.items[i - 1])
            i -= 1;

        builder.trivial.items[i - 1] = true;
        popped += 1;
    }
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
    var builder = Builders.init(a);
    defer builder.deinit();

    // tracks comment state
    var comments = Comments{};

    // read/write indices
    var rd: usize = 0;
    var wr: usize = 0;

    while (rd < lines.inner.items.len) {
        const line = lines.inner.items[rd];
        for (line.items) |ch, i| {
            try builder.text.append(ch);
            try builder.trivial.append(line.trivial[i]);
            try builder.synthetic.append(line.synthetic[i]);

            if (shouldEmit(ch, &comments)) |emit| {
                backtrack(&builder, emit.pop_count);
                if (emit.ch != ch)
                    try builder.append(.{
                        .ch = emit.ch,
                        .trivial = false,
                        .synthetic = true,
                    });
            } else builder.trivial.items[builder.trivial.items.len - 1] = true;

            if (!line.trivial[i])
                comments.prev_char = ch;
        }

        if (!comments.in_block_comment) {
            // copy the line to output
            lines.inner.items[wr].replace(
                try Line.initAlloc(
                    a,
                    try builder.text.toOwnedSlice(),
                    .{
                        .trivial = try builder.trivial.toOwnedSlice(),
                        .synthetic = try builder.synthetic.toOwnedSlice(),
                    },
                ),
            );
            wr += 1;
        }

        rd += 1;
    }

    lines.shrink(wr);
}

fn esc(ch: u8) []const u8 {
    return switch (ch) {
        '\n' => "\\n",
        '\r' => "\\r",
        '\t' => "\\t",
        '\\' => "\\\\",
        else => &[_]u8{ch},
    };
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
    errdefer {
        for (lines.inner.items) |line, i| {
            std.debug.print("=== LINE {d} ===\n", .{i + 1});
            for (line.items) |ch, j| {
                std.debug.print("'{s}' is {s}trivial\n", .{
                    .c = esc(ch),
                    .s = if (line.trivial[j]) "" else "not ",
                });
            }
        }
    }
    const expected_joined = try std.mem.join(std.testing.allocator, "\n", expected);
    defer std.testing.allocator.free(expected_joined);
    var actual_joined = std.ArrayList(u8).init(std.testing.allocator);
    defer actual_joined.deinit();
    for (lines.inner.items) |line| {
        const nontrivial = try line.getNonTrivial(std.testing.allocator);
        defer std.testing.allocator.free(nontrivial);
        try actual_joined.appendSlice(nontrivial);
    }
    try std.testing.expectEqualStrings(expected_joined, actual_joined.items);
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
        \\  printf("foo // \"bar\" baz");
        \\}
    ;
    const expected = [_][]const u8{
        "#include <stdio.h>",
        "",
        "int main() {",
        "  printf(\"foo // \\\"bar\\\" baz\");",
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

test "line comment at eof" {
    const input = "foo bar baz // this is a line comment";
    const expected = [_][]const u8{"foo bar baz  "};
    try testInput(input, &expected);
}
