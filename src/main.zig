const std = @import("std");
const initial = @import("initial");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.detectLeaks();
    const a = gpa.allocator();

    var lines = try initial.breakLines(a, try initial.readIn(a, "main.c"));
    try initial.mergeEscapedNewlines(&lines);
    try initial.delComments(&lines);
    for (lines.inner.items) |line| {
        std.debug.print("{s}\n", .{line.items});
    }
}
