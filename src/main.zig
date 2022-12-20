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
    var initial_arena = std.heap.ArenaAllocator.init(a);
    const raw = try initial.readIn(initial_arena.allocator(), filename);
    var lines = try initial.breakLines(initial_arena.allocator(), raw);
    try initial.mergeEscapedNewlines(&lines);
    try initial.delComments(&lines);
    const input = try initial.unlines(a, lines);
    initial_arena.deinit();
    defer a.free(input);

    const tokens = try preprocessor.lexer.lex(a, input);
    defer a.free(tokens);

    for (tokens) |tok| {
        std.debug.print("{}\n", .{tok.kind});
    }
}
