const std = @import("std");

text: std.ArrayList(u8),
trivial: std.ArrayList(bool),
synthetic: std.ArrayList(bool),

pub const CharInfo = struct {
    ch: u8,
    trivial: bool,
    synthetic: bool,
};

pub fn init(alloc: std.mem.Allocator) @This() {
    return .{
        .text = std.ArrayList(u8).init(alloc),
        .trivial = std.ArrayList(bool).init(alloc),
        .synthetic = std.ArrayList(bool).init(alloc),
    };
}

pub fn deinit(self: @This()) void {
    self.text.deinit();
    self.trivial.deinit();
    self.synthetic.deinit();
}

pub fn clear(self: *@This()) void {
    self.text.clearRetainingCapacity();
    self.trivial.clearRetainingCapacity();
    self.synthetic.clearRetainingCapacity();
}

pub fn append(self: *@This(), info: CharInfo) !void {
    try self.text.append(info.ch);
    try self.trivial.append(info.trivial);
    try self.synthetic.append(info.synthetic);
}
