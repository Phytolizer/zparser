const std = @import("std");

a: std.mem.Allocator,
macros: std.StringHashMap([]u8),

pub fn init(a: std.mem.Allocator) @This() {
    return .{
        .a = a,
        .macros = std.StringHashMap([]u8).init(a),
    };
}

pub fn deinit(self: @This()) void {
    var macro_it = self.macros.iterator();
    while (macro_it.next()) |ent| {
        self.a.free(ent.key_ptr.*);
        self.a.free(ent.value_ptr.*);
    }
    self.macros.deinit();
}
