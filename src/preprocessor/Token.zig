const std = @import("std");

kind: Kind,

pub const Kind = union(enum) {
    // normal C identifier rules
    ident: []const u8,
    // string constant ("") OR character constant ('') OR header name (<>)
    string_lit: []const u8,
    // something that "looks like" a number (not necessarily valid)
    number: []const u8,
    // anything but `, @, and $
    punctuator: u8,
    // anything else
    other: []const u8,
    // end of file marker
    eof,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .ident => |ident| try writer.print("{{ident '{s}'}}", .{ident}),
            .string_lit => |string_lit| try writer.print("{{string_lit '{s}'}}", .{string_lit}),
            .number => |number| try writer.print("{{number '{s}'}}", .{number}),
            .punctuator => |punctuator| try writer.print("{{punctuator '{c}'}}", .{punctuator}),
            .other => |other| try writer.print("{{other '{s}'}}", .{other}),
            .eof => try writer.writeAll("{EOF}"),
        }
    }
};
