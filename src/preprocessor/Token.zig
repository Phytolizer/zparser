const std = @import("std");

kind: Kind,

pub const Kind = union(enum) {
    // normal C identifier rules
    ident: []const u8,
    // string constant ("") OR character constant ('') OR header name (<>)
    string_lit: []const u8,
    // something that "looks like" a number (not necessarily valid)
    number: []const u8,
    // operator or punctuator
    punct: enum {
        // always operators
        period,
        arrow,
        plus_plus,
        minus_minus,
        amp,
        plus,
        minus,
        tilde,
        bang,
        slash,
        percent,
        lt_lt,
        gt_gt,
        lt,
        gt,
        lt_eq,
        gt_eq,
        eq_eq,
        bang_eq,
        caret,
        pipe,
        amp_amp,
        pipe_pipe,
        question,
        star_eq,
        slash_eq,
        percent_eq,
        plus_eq,
        minus_eq,
        lt_lt_eq,
        gt_gt_eq,
        amp_eq,
        caret_eq,
        pipe_eq,
        hash_hash,

        // could be either
        lbrack,
        rbrack,
        lparen,
        rparen,
        star,
        comma,
        colon,
        eq,
        hash,

        // always punctuators
        lbrace,
        rbrace,
        semicolon,
        ellipsis,
    },
    // anything else
    other: []const u8,
    // end of line marker
    eol,
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
            .punct => |p| try writer.print("{{punct {s}}}", .{std.meta.fieldNames(@TypeOf(p))[@enumToInt(p)]}),
            .other => |other| try writer.print("{{other '{s}'}}", .{other}),
            .eol => try writer.writeAll("{EOL}"),
            .eof => try writer.writeAll("{EOF}"),
        }
    }
};
