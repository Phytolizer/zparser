const std = @import("std");
const initial = @import("initial");
const preprocessor = @import("preprocessor");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.detectLeaks();
    const a = gpa.allocator();

    var args = std.process.args();
    _ = args.next();
    const filename = args.next() orelse return error.InvalidInput;
    var lines = try initial.breakLines(a, try initial.readIn(a, filename));
    try initial.mergeEscapedNewlines(&lines);
    try initial.delComments(&lines);
    const input = try initial.unlines(lines);
    defer a.free(input);

    const tokens = try preprocessor.lexer.lex(a, input);
    defer a.free(tokens);

    for (tokens) |tok| {
        std.debug.print("{}\n", .{tok.kind});
    }
}
