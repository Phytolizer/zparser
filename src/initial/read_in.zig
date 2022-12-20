const std = @import("std");

/// Reads the contents of a file into a byte array.
///
/// Args:
/// - `a`: The allocator to use for creating the output byte array.
/// - `path`: The path to the file to be read.
///
/// Returns:
/// The contents of the file as a byte array.
pub fn read_in(a: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return try file.readToEndAlloc(a, std.math.maxInt(usize));
}
