const std = @import("std");
const Line = @import("Line.zig");
const Lines = @import("Lines.zig");
const Builders = @import("Builders.zig");

/// Merge lines in the `lines` array if the previous line ends with a backslash
/// character.
///
/// When a line is merged with the previous line, the backslash and the line
/// ending sequence are removed.
///
/// Args:
/// - `lines`: A pointer to an array of `Line` objects. The modified array is
///            returned via this argument.
pub fn mergeEscapedNewlines(lines: *Lines) !void {
    const a = lines.inner.allocator;
    // holds merged lines temporarily
    var builder = Builders.init(a);
    defer builder.deinit();
    // read/write indices
    var rd: usize = 0;
    var wr: usize = 0;

    while (rd < lines.inner.items.len) {
        const line = &lines.inner.items[rd];
        if (std.mem.endsWith(u8, line.items, "\\\n")) {
            // remove the backslash, keep building line
            try builder.text.appendSlice(line.items);
            try builder.synthetic.appendSlice(line.synthetic);

            // backslash and newline are now trivial
            try builder.trivial.appendSlice(
                line.trivial[0 .. line.trivial.len - 2],
            );
            try builder.trivial.appendSlice(&.{ true, true });
        } else {
            if (builder.text.items.len == 0) {
                // if builder is empty, just take the line as-is
                lines.inner.items[wr].replace(try Line.initRef(
                    a,
                    line.items,
                    .{
                        .trivial = line.takeTrivial(),
                        .synthetic = line.takeSynthetic(),
                    },
                ));
                wr += 1;
            } else {
                // otherwise, append the line to the builder and take the result
                try builder.text.appendSlice(line.items);
                try builder.trivial.appendSlice(line.trivial);
                try builder.synthetic.appendSlice(line.synthetic);
                lines.inner.items[wr].replace(try Line.initAlloc(
                    a,
                    try builder.text.toOwnedSlice(),
                    .{
                        .trivial = try builder.trivial.toOwnedSlice(),
                        .synthetic = try builder.synthetic.toOwnedSlice(),
                    },
                ));
                builder.clear();
                wr += 1;
            }
        }

        rd += 1;
    }

    // if anything leftover, take it
    if (builder.text.items.len > 0) {
        lines.inner.items[wr].replace(try Line.initAlloc(
            a,
            try builder.text.toOwnedSlice(),
            .{
                .trivial = try builder.trivial.toOwnedSlice(),
                .synthetic = try builder.synthetic.toOwnedSlice(),
            },
        ));
        wr += 1;
    }

    // cut off the end
    lines.shrink(wr);
}

fn testInput(input: []const u8, expected: []const []const u8) !void {
    const dupe_input = try std.testing.allocator.dupe(u8, input);
    var lines = try @import("break_lines.zig").breakLines(
        std.testing.allocator,
        dupe_input,
    );
    defer lines.deinit();
    try mergeEscapedNewlines(&lines);
    const expected_joined =
        try std.mem.join(std.testing.allocator, "\n", expected);
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

test "escaped newline" {
    const input =
        \\#include <stdio.h>
        \\
        \\int main() {
        \\  printf("hi \
        \\mom\n");
        \\}
    ;
    const expected = [_][]const u8{
        "#include <stdio.h>",
        "",
        "int main() {",
        "  printf(\"hi mom\\n\");",
        "}",
    };
    try testInput(input, &expected);
}

test "no escaped newlines" {
    const input =
        \\#include <stdio.h>
        \\
        \\int main() {
        \\  printf("hi mom\n");
        \\}
    ;
    const expected = [_][]const u8{
        "#include <stdio.h>",
        "",
        "int main() {",
        "  printf(\"hi mom\\n\");",
        "}",
    };
    try testInput(input, &expected);
}

test "multiple escaped newlines" {
    const input =
        \\#include <stdio.h>
        \\
        \\int main() {
        \\  printf("hi \
        \\mom \
        \\how are you?\n");
        \\}
    ;
    const expected = [_][]const u8{
        "#include <stdio.h>",
        "",
        "int main() {",
        "  printf(\"hi mom how are you?\\n\");",
        "}",
    };
    try testInput(input, &expected);
}

test "empty escaped newline" {
    const input =
        \\#include <stdio.h>
        \\
        \\int main() {
        \\  printf("hi \
        \\\
        \\mom\n");
        \\}
    ;
    const expected = [_][]const u8{
        "#include <stdio.h>",
        "",
        "int main() {",
        "  printf(\"hi mom\\n\");",
        "}",
    };
    try testInput(input, &expected);
}

test "do not remove backslash at end of file" {
    const input =
        \\#include <stdio.h>
        \\
        \\int main() {
        \\  printf("hi \
        \\mom");
        \\}
        \\\
    ;
    const expected = [_][]const u8{
        "#include <stdio.h>",
        "",
        "int main() {",
        "  printf(\"hi mom\");",
        "}",
        "\\",
    };
    try testInput(input, &expected);
}
