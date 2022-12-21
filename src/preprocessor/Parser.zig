//! C Preprocessor Parser
//!
//! The parser ignores everything except `.ident` tokens, and directives.
//!
//! Directives are delimited by `.hash` (at the start) and `.eol` (at the end).
//! The processed lines will be replaced with their output.
//!
//! If an `.ident` token names a defined macro in the macro table, it will be
//! replaced with its definition.
//!
//! For example, the line `#define A 10` will be replaced with nothing.
//! However, the text `10` will be stored in the macro table.
//! If `A` appears on a subsequent line, it will be replaced by `10`.
//!
//! Another example: the line `#include "a.h"` will search the filesystem for
//! a file called "a.h", and replace the directive with its full contents.

const std = @import("std");
const MacroTable = @import("MacroTable.zig");
const Token = @import("Token.zig");

a: std.mem.Allocator,
macros: MacroTable,
tokens: []const Token,

pub fn init(a: std.mem.Allocator, tokens: []const Token) @This() {
    return .{
        .a = a,
        .macros = MacroTable.init(a),
        .tokens = tokens,
    };
}

pub fn deinit(self: @This()) void {
    self.macros.deinit();
}
