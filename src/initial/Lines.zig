const std = @import("std");
const Line = @import("Line.zig");

inner: std.ArrayList(Line),

pub fn init(lines: std.ArrayList(Line)) !@This() {
    return .{ .inner = lines };
}

pub fn deinit(self: @This()) void {
    for (self.inner.items) |line| {
        line.deinit();
    }
    self.inner.deinit();
}

pub fn shrink(self: *@This(), new_len: usize) void {
    for (self.inner.items[new_len..]) |line| {
        line.deinit();
    }
    self.inner.shrinkRetainingCapacity(new_len);
}
