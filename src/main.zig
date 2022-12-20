const std = @import("std");
const initial = @import("initial");

pub fn main() !void {
    var lines = try initial.break_lines(
        std.testing.allocator,
        try initial.read_in(std.testing.allocator, "main.c"),
    );
    try initial.merge_escaped_newlines(&lines);
    for (lines.inner.items) |line| {
        std.debug.print("{s}\n", .{line.items});
    }
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
