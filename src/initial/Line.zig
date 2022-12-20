const std = @import("std");

a: ?std.mem.Allocator = null,
items: []u8,

pub fn initAlloc(a: std.mem.Allocator, initial: []u8) @This() {
    return .{
        .a = a,
        .items = initial,
    };
}

pub fn initRef(initial: []u8) @This() {
    return .{ .items = initial };
}

pub fn deinit(self: @This()) void {
    if (self.a) |a|
        a.free(self.items);
}

pub fn replace(self: *@This(), new: @This()) void {
    self.deinit();
    self.* = new;
}
