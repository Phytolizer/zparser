const std = @import("std");

a: std.mem.Allocator,
items: []u8,
own_items: bool,
trivial: []bool,
own_trivial: bool = true,
synthetic: []bool,
own_synthetic: bool = true,

const InitArgs = struct {
    trivial: ?[]bool = null,
    synthetic: ?[]bool = null,
};

fn createBools(a: std.mem.Allocator, len: usize) ![]bool {
    const result = try a.alloc(bool, len);
    std.mem.set(bool, result, false);
    return result;
}

pub fn initAlloc(
    a: std.mem.Allocator,
    initial: []u8,
    info: InitArgs,
) !@This() {
    return .{
        .a = a,
        .items = initial,
        .own_items = true,
        .trivial = info.trivial orelse try createBools(a, initial.len),
        .synthetic = info.synthetic orelse try createBools(a, initial.len),
    };
}

pub fn initRef(
    a: std.mem.Allocator,
    initial: []u8,
    info: InitArgs,
) !@This() {
    return .{
        .a = a,
        .items = initial,
        .own_items = false,
        .trivial = info.trivial orelse try createBools(a, initial.len),
        .synthetic = info.synthetic orelse try createBools(a, initial.len),
    };
}

pub fn deinit(self: @This()) void {
    if (self.own_items)
        self.a.free(self.items);
    if (self.own_trivial)
        self.a.free(self.trivial);
    if (self.own_synthetic)
        self.a.free(self.synthetic);
}

pub fn replace(self: *@This(), new: @This()) void {
    self.deinit();
    self.* = new;
}

pub fn takeTrivial(self: *@This()) []bool {
    self.own_trivial = false;
    return self.trivial;
}

pub fn takeSynthetic(self: *@This()) []bool {
    self.own_synthetic = false;
    return self.synthetic;
}

pub fn getNonTrivial(self: @This(), a: std.mem.Allocator) ![]u8 {
    var result = std.ArrayList(u8).init(a);
    for (self.items) |ch, i| {
        if (!self.trivial[i])
            try result.append(ch);
    }
    return try result.toOwnedSlice();
}
