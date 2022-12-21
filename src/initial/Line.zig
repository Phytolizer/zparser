const std = @import("std");

a: std.mem.Allocator,
items: []u8,
own_items: bool,
trivial: []bool,

pub fn initAlloc(a: std.mem.Allocator, initial: []u8) !@This() {
    var trivial = try a.alloc(bool, initial.len);
    std.mem.set(bool, trivial, false);
    return .{
        .a = a,
        .items = initial,
        .own_items = true,
        .trivial = trivial,
    };
}

pub fn initRef(a: std.mem.Allocator, initial: []u8) !@This() {
    var trivial = try a.alloc(bool, initial.len);
    std.mem.set(bool, trivial, false);
    return .{
        .a = a,
        .items = initial,
        .own_items = false,
        .trivial = trivial,
    };
}

pub fn deinit(self: @This()) void {
    if (self.own_items)
        self.a.free(self.items);
    self.a.free(self.trivial);
}

pub fn replace(self: *@This(), new: @This()) void {
    self.deinit();
    self.* = new;
}
