const std = @import("std");
const Line = @import("Line.zig");
const Lines = @import("Lines.zig");

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
    var builder = std.ArrayList(u8).init(a);
    defer builder.deinit();
    // read/write indices
    var rd: usize = 0;
    var wr: usize = 0;

    while (rd < lines.inner.items.len) {
        const line = lines.inner.items[rd].items;
        if (std.mem.endsWith(u8, line, "\\\n")) {
            // remove the backslash, keep building line
            try builder.appendSlice(line[0 .. line.len - 2]);
        } else {
            if (builder.items.len == 0) {
                // if builder is empty, just take the line as-is
                lines.inner.items[wr].replace(try Line.initRef(a, line));
                wr += 1;
            } else {
                // otherwise, append the line to the builder and take the result
                try builder.appendSlice(line);
                lines.inner.items[wr].replace(
                    try Line.initAlloc(a, try builder.toOwnedSlice()),
                );
                builder.clearRetainingCapacity();
                wr += 1;
            }
        }

        rd += 1;
    }

    // if anything leftover, take it
    if (builder.items.len > 0) {
        lines.inner.items[wr].replace(
            try Line.initAlloc(a, try builder.toOwnedSlice()),
        );
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
    try std.testing.expectEqual(expected.len, lines.inner.items.len);
    for (expected) |line, i| {
        try std.testing.expectEqualStrings(line, lines.inner.items[i].items);
    }
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
        "#include <stdio.h>\n",
        "\n",
        "int main() {\n",
        "  printf(\"hi mom\\n\");\n",
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
        "#include <stdio.h>\n",
        "\n",
        "int main() {\n",
        "  printf(\"hi mom\\n\");\n",
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
        "#include <stdio.h>\n",
        "\n",
        "int main() {\n",
        "  printf(\"hi mom how are you?\\n\");\n",
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
        "#include <stdio.h>\n",
        "\n",
        "int main() {\n",
        "  printf(\"hi mom\\n\");\n",
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
        "#include <stdio.h>\n",
        "\n",
        "int main() {\n",
        "  printf(\"hi mom\");\n",
        "}\n",
        "\\",
    };
    try testInput(input, &expected);
}
