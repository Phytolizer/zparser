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
pub fn merge_escaped_newlines(lines: *Lines) !void {
    const a = lines.inner.allocator;
    // holds merged lines temporarily
    var builder = std.ArrayList(u8).init(a);
    defer builder.deinit();
    // read/write indices
    var rd: usize = 0;
    var wr: usize = 0;

    while (rd < lines.inner.items.len) {
        const line = lines.inner.items[rd].items;
        if (std.mem.endsWith(u8, line, "\\")) {
            // remove the backslash, keep building line
            try builder.appendSlice(line[0 .. line.len - 1]);
        } else {
            if (builder.items.len == 0) {
                // if builder is empty, just take the line as-is
                lines.inner.items[wr].replace(Line.initRef(line));
                wr += 1;
            } else {
                // otherwise, append the line to the builder and take the result
                try builder.appendSlice(line);
                lines.inner.items[wr].replace(
                    Line.initAlloc(a, try builder.toOwnedSlice()),
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
            Line.initAlloc(a, try builder.toOwnedSlice()),
        );
        wr += 1;
    }

    // cut off the end
    lines.shrink(wr);
}

test "escaped newline" {
    const input = @embedFile("tests/escaped_newline.c");
    const dupe_input = try std.testing.allocator.dupe(u8, input);
    defer std.testing.allocator.free(dupe_input);
    var lines = try @import("break_lines.zig").break_lines(
        std.testing.allocator,
        dupe_input,
    );
    defer lines.deinit();
    try @import("merge_escaped_newlines.zig").merge_escaped_newlines(&lines);
    const expected = [_][]const u8{
        "#include <stdio.h>",
        "",
        "int main() {",
        "  printf(\"ur mom\\n\");",
        "}",
    };
    try std.testing.expectEqual(expected.len, lines.inner.items.len);
    for (expected) |line, i| {
        try std.testing.expectEqualStrings(line, lines.inner.items[i].items);
    }
}
