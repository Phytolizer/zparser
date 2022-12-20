const std = @import("std");
const Line = @import("Line.zig");
const Lines = @import("Lines.zig");

pub fn merge_escaped_newlines(lines: *Lines) !void {
    const a = lines.inner.allocator;
    var builder = std.ArrayList(u8).init(a);
    defer builder.deinit();
    var rd: usize = 0;
    var wr: usize = 0;
    while (rd < lines.inner.items.len) : (rd += 1) {
        const line = lines.inner.items[rd].items;
        if (line.len > 0 and line[line.len - 1] == '\\') {
            try builder.appendSlice(line[0 .. line.len - 1]);
        } else {
            if (builder.items.len == 0) {
                lines.inner.items[wr].replace(Line.initRef(line));
                wr += 1;
                continue;
            }

            try builder.appendSlice(line);
            lines.inner.items[wr].replace(
                Line.initAlloc(a, try builder.toOwnedSlice()),
            );
            builder.shrinkRetainingCapacity(0);
            wr += 1;
        }
    }

    if (builder.items.len > 0) {
        lines.inner.items[wr].replace(
            Line.initAlloc(a, try builder.toOwnedSlice()),
        );
        wr += 1;
    }

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
