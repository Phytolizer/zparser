const std = @import("std");
const Token = @import("Token.zig");

const Lexer = struct {
    input: []const u8,
    pos: usize = 0,
    at_line_start: bool = true,
    in_directive: bool = false,

    pub fn init(input: []const u8) @This() {
        return .{ .input = input };
    }

    fn get(self: @This()) ?u8 {
        if (self.pos >= self.input.len) return null;
        return self.input[self.pos];
    }

    fn move(self: *@This()) void {
        const c = self.get();
        self.pos += 1;
        if (c != null and c.? == '\n') {
            self.at_line_start = true;
            self.in_directive = false;
        }
    }

    fn isHash(tk: Token.Kind) bool {
        return switch (tk) {
            .punctuator => |p| p == '#',
            else => false,
        };
    }

    fn endToken(self: *@This(), tk: Token.Kind) Token {
        if (self.at_line_start and isHash(tk))
            self.in_directive = true;

        return .{ .kind = tk };
    }

    fn skipWhitespace(self: *@This()) void {
        while (self.get()) |ch| switch (ch) {
            ' ', '\t', '\r', '\n' => self.move(),
            else => break,
        };
    }

    fn scanIdent(self: *@This()) Token {
        const start = self.pos;
        while (self.get()) |ch| switch (ch) {
            'a'...'z', 'A'...'Z', '0'...'9', '_' => self.move(),
            else => break,
        };
        const end = self.pos;
        return self.endToken(.{ .ident = self.input[start..end] });
    }

    fn scanNumber(self: *@This()) ?Token {
        const first = self.get().?;
        const start = self.pos;
        self.move();
        const is_number = if (first != '.')
            true
        else if (self.get()) |second| switch (second) {
            '0'...'9' => true,
            else => false,
        } else false;

        if (!is_number) {
            self.pos = start;
            return null;
        }

        while (self.get()) |ch| switch (ch) {
            '0'...'9',
            '.',
            'a'...'d',
            // skip e, handled below
            'f'...'o',
            // skip p, handled below
            'q'...'z',
            'A'...'D',
            // skip E, handled below
            'F'...'O',
            // skip P, handled below
            'Q'...'Z',
            '_',
            => self.move(),
            'e', 'E', 'p', 'P' => {
                self.move();
                if (self.get()) |second| switch (second) {
                    '+', '-' => self.move(),
                    else => {},
                };
            },
            else => break,
        };
        const end = self.pos;
        return self.endToken(.{ .number = self.input[start..end] });
    }

    // Returns .other if the string literal is unterminated by EOL.
    fn scanStringLit(self: *@This()) ?Token {
        const first = self.get().?;
        const terminator: u8 = switch (first) {
            '"' => '"',
            '\'' => '\'',
            '<' => '>',
            else => unreachable,
        };
        const start = self.pos;
        self.move();
        if (self.get()) |ch| if (ch == ':' or ch == '%') {
            // digraph, handle it in scanPunct()
            self.pos = start;
            return null;
        };
        while (self.get()) |ch| if (ch == terminator) {
            self.move();
            const end = self.pos;
            return self.endToken(.{ .string_lit = self.input[start..end] });
        } else if (ch == '\\' and first != '<') {
            // skip escaped character
            self.move();
            if (self.get()) |_| self.move();
        } else switch (ch) {
            '\n' => break, // unterminated
            else => self.move(),
        };

        if (first == '<') {
            // don't be greedy, `<` could have been a normal punctuator
            self.pos = start;
            // next() will check for digraph now
            return null;
        }
        // unterminated string literal
        const end = self.pos;
        return self.endToken(.{ .other = self.input[start..end] });
    }

    fn scanPunct(self: *@This()) Token {
        // Get the first character and advance the position.
        const first = self.get().?;
        self.move();

        // Handle digraphs.
        switch (first) {
            '<' => if (self.get()) |second| switch (second) {
                ':' => {
                    self.move();
                    return self.endToken(.{ .punctuator = '[' });
                },
                '%' => {
                    self.move();
                    return self.endToken(.{ .punctuator = '{' });
                },
                else => {},
            },
            '%' => if (self.get()) |second| switch (second) {
                '>' => {
                    self.move();
                    return self.endToken(.{ .punctuator = '}' });
                },
                ':' => {
                    self.move();
                    return self.endToken(.{ .punctuator = '#' });
                },
                else => {},
            },
            ':' => if (self.get()) |second| if (second == '>') {
                self.move();
                return self.endToken(.{ .punctuator = ']' });
            },
            else => {},
        }

        // Otherwise, return the character.
        return self.endToken(.{ .punctuator = first });
    }

    pub fn scanOther(self: *@This()) Token {
        const start = self.pos;
        self.move();
        return self.endToken(.{ .other = self.input[start..self.pos] });
    }

    pub fn next(self: *@This()) ?Token {
        self.skipWhitespace();
        if (self.get()) |first| switch (first) {
            'a'...'z', 'A'...'Z', '_' => return self.scanIdent(),
            '0'...'9', '.' => return self.scanNumber() orelse {
                // `.` could have been a normal punctuator
                return self.scanPunct();
            },
            '"', '\'', '<' => {
                if (self.in_directive or first != '<')
                    if (self.scanStringLit()) |sl| return sl;
                // `<` could have been a normal punctuator
                return self.scanPunct();
            },
            // This part is awkward because of the other symbols handled above.
            // We can't do a whole range because it would overlap,
            // and that's not allowed in switch statements.
            '!',
            '#',
            '%'...'&',
            '('...'-',
            '/',
            ':'...';',
            '='...'?',
            '['...'^',
            '{'...'~',
            => return self.scanPunct(),
            else => return self.scanOther(),
        };
        return null;
    }
};

pub fn lex(a: std.mem.Allocator, input: []const u8) ![]Token {
    var lexer = Lexer.init(input);
    var tokens = std.ArrayList(Token).init(a);
    while (lexer.next()) |tok| {
        try tokens.append(tok);
    }

    try tokens.append(.{ .kind = .eof });

    return try tokens.toOwnedSlice();
}

fn testInput(input: []const u8, expected: []const Token) !void {
    const result = try lex(std.testing.allocator, input);
    defer std.testing.allocator.free(result);
    errdefer {
        std.debug.print("expected:\n", .{});
        for (expected) |tok| {
            std.debug.print("    {any}\n", .{tok.kind});
        }
        std.debug.print("result:\n", .{});
        for (result) |tok| {
            std.debug.print("    {any}\n", .{tok.kind});
        }
    }

    try std.testing.expectEqual(expected.len, result.len);
    const str = struct {
        fn str(t: Token) ?[]const u8 {
            return switch (t.kind) {
                .ident, .number, .string_lit, .other => |s| s,
                else => null,
            };
        }
    }.str;
    for (expected) |tok, i| {
        if (str(tok)) |t| {
            try std.testing.expectEqualStrings(t, str(result[i]).?);
        } else {
            try std.testing.expectEqual(tok, result[i]);
        }
    }
}

test "empty file" {
    try testInput("", &[_]Token{.{ .kind = .eof }});
}

test "whitespace" {
    try testInput(" \t\r\n", &[_]Token{.{ .kind = .eof }});
}

test "identifiers" {
    try testInput("a b c", &[_]Token{
        .{ .kind = .{ .ident = "a" } },
        .{ .kind = .{ .ident = "b" } },
        .{ .kind = .{ .ident = "c" } },
        .{ .kind = .eof },
    });
}

test "numbers" {
    try testInput("1 2.3 4. 5e6 7e+8 9e-10", &[_]Token{
        .{ .kind = .{ .number = "1" } },
        .{ .kind = .{ .number = "2.3" } },
        .{ .kind = .{ .number = "4." } },
        .{ .kind = .{ .number = "5e6" } },
        .{ .kind = .{ .number = "7e+8" } },
        .{ .kind = .{ .number = "9e-10" } },
        .{ .kind = .eof },
    });
}

test "punctuators" {
    try testInput("()[]{}:;.,->*+&|~^!%/?=<", &[_]Token{
        .{ .kind = .{ .punctuator = '(' } },
        .{ .kind = .{ .punctuator = ')' } },
        .{ .kind = .{ .punctuator = '[' } },
        .{ .kind = .{ .punctuator = ']' } },
        .{ .kind = .{ .punctuator = '{' } },
        .{ .kind = .{ .punctuator = '}' } },
        .{ .kind = .{ .punctuator = ':' } },
        .{ .kind = .{ .punctuator = ';' } },
        .{ .kind = .{ .punctuator = '.' } },
        .{ .kind = .{ .punctuator = ',' } },
        .{ .kind = .{ .punctuator = '-' } },
        .{ .kind = .{ .punctuator = '>' } },
        .{ .kind = .{ .punctuator = '*' } },
        .{ .kind = .{ .punctuator = '+' } },
        .{ .kind = .{ .punctuator = '&' } },
        .{ .kind = .{ .punctuator = '|' } },
        .{ .kind = .{ .punctuator = '~' } },
        .{ .kind = .{ .punctuator = '^' } },
        .{ .kind = .{ .punctuator = '!' } },
        .{ .kind = .{ .punctuator = '%' } },
        .{ .kind = .{ .punctuator = '/' } },
        .{ .kind = .{ .punctuator = '?' } },
        .{ .kind = .{ .punctuator = '=' } },
        .{ .kind = .{ .punctuator = '<' } },
        .{ .kind = .eof },
    });
}

test "strings" {
    try testInput("\"a\" 'b'", &[_]Token{
        .{ .kind = .{ .string_lit = "\"a\"" } },
        .{ .kind = .{ .string_lit = "'b'" } },
        .{ .kind = .eof },
    });
}

test "c-like" {
    try testInput(
        \\#include <stdio.h>
        \\int main() {
        \\    printf("Hello, world!");
        \\    return 0;
        \\}
    , &[_]Token{
        .{ .kind = .{ .punctuator = '#' } },
        .{ .kind = .{ .ident = "include" } },
        .{ .kind = .{ .string_lit = "<stdio.h>" } },
        .{ .kind = .{ .ident = "int" } },
        .{ .kind = .{ .ident = "main" } },
        .{ .kind = .{ .punctuator = '(' } },
        .{ .kind = .{ .punctuator = ')' } },
        .{ .kind = .{ .punctuator = '{' } },
        .{ .kind = .{ .ident = "printf" } },
        .{ .kind = .{ .punctuator = '(' } },
        .{ .kind = .{ .string_lit = "\"Hello, world!\"" } },
        .{ .kind = .{ .punctuator = ')' } },
        .{ .kind = .{ .punctuator = ';' } },
        .{ .kind = .{ .ident = "return" } },
        .{ .kind = .{ .number = "0" } },
        .{ .kind = .{ .punctuator = ';' } },
        .{ .kind = .{ .punctuator = '}' } },
        .{ .kind = .eof },
    });
}

test "digraphs" {
    try testInput(
        \\<: :> <: :>
        \\<% %> <% %>
        \\%: %:%:
        \\%:%:
    , &[_]Token{
        .{ .kind = .{ .punctuator = '[' } },
        .{ .kind = .{ .punctuator = ']' } },
        .{ .kind = .{ .punctuator = '[' } },
        .{ .kind = .{ .punctuator = ']' } },
        .{ .kind = .{ .punctuator = '{' } },
        .{ .kind = .{ .punctuator = '}' } },
        .{ .kind = .{ .punctuator = '{' } },
        .{ .kind = .{ .punctuator = '}' } },
        .{ .kind = .{ .punctuator = '#' } },
        .{ .kind = .{ .punctuator = '#' } },
        .{ .kind = .{ .punctuator = '#' } },
        .{ .kind = .{ .punctuator = '#' } },
        .{ .kind = .{ .punctuator = '#' } },
        .{ .kind = .eof },
    });
}

test "angle brackets are not an include" {
    try testInput("3<4&&4>5", &[_]Token{
        .{ .kind = .{ .number = "3" } },
        .{ .kind = .{ .punctuator = '<' } },
        .{ .kind = .{ .number = "4" } },
        .{ .kind = .{ .punctuator = '&' } },
        .{ .kind = .{ .punctuator = '&' } },
        .{ .kind = .{ .number = "4" } },
        .{ .kind = .{ .punctuator = '>' } },
        .{ .kind = .{ .number = "5" } },
        .{ .kind = .eof },
    });
}

test "string escape" {
    try testInput("\"\\\"\\n\\t\\\\\"", &[_]Token{
        .{ .kind = .{ .string_lit = "\"\\\"\\n\\t\\\\\"" } },
        .{ .kind = .eof },
    });
}

test "char escape" {
    try testInput("'\\''", &[_]Token{
        .{ .kind = .{ .string_lit = "'\\''" } },
        .{ .kind = .eof },
    });
}

test "header name is not escaped" {
    try testInput("#include <\\>>", &[_]Token{
        .{ .kind = .{ .punctuator = '#' } },
        .{ .kind = .{ .ident = "include" } },
        .{ .kind = .{ .string_lit = "<\\>" } },
        .{ .kind = .{ .punctuator = '>' } },
        .{ .kind = .eof },
    });
}

test "unterminated string" {
    try testInput("\"hi world\nbye", &[_]Token{
        .{ .kind = .{ .other = "\"hi world" } },
        .{ .kind = .{ .ident = "bye" } },
        .{ .kind = .eof },
    });
}
