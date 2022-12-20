const std = @import("std");

a: ?std.mem.Allocator = null,
is_alloc: bool = false,
items: []u8,

pub fn initAlloc(a: std.mem.Allocator, initial: []u8) @This() {
    return .{
        .a = a,
        .is_alloc = true,
        .items = initial,
    };
}

pub fn initRef(initial: []u8) @This() {
    return .{ .items = initial };
}

pub fn deinit(self: @This()) void {
    if (self.is_alloc) {
        self.a.?.free(self.items);
    }
}

pub fn replace(self: *@This(), new: @This()) void {
    self.deinit();
    self.* = new;
}
