const std = @import("std");
const Parser = @import("parser.zig");
const Result = Parser.Result;
const ParserFn = Parser.ParserFn;

pub const AsciiError = Parser.Error([]const u8);

pub fn AsciiParserFn(comptime T: type) type {
    return ParserFn([]const u8, T, Parser.Error([]const u8));
}

pub fn AsciiResult(comptime T: type, comptime E: type) type {
    return Result([]const u8, T, E);
}

pub fn Satisfy(comptime Pred: fn (u8) bool) AsciiParserFn(u8) {
    return struct {
        const R = AsciiResult(u8, AsciiError);
        pub inline fn satisfy(input: []const u8, _: std.mem.Allocator) anyerror!R {
            if (input.len == 0) {
                return R{ .err = .fromKind(input, .Satisfy) };
            }

            if (!Pred(input[0])) {
                return R{ .err = .fromKind(input, .Satisfy) };
            }

            return R{ .res = .{ input[1..], input[0] } };
        }
    }.satisfy;
}

pub fn Char(comptime C: u8) AsciiParserFn(u8) {
    return struct {
        const R = AsciiResult(u8, AsciiError);
        pub inline fn char(input: []const u8, _: std.mem.Allocator) anyerror!R {
            if (input.len == 0) {
                return R{ .err = .fromKind(input, .Char) };
            }

            if (input[0] != C) {
                return R{ .err = .fromKind(input, .Char) };
            }

            return R{ .res = .{ input[1..], C } };
        }
    }.char;
}

pub fn String(comptime Str: []const u8) AsciiParserFn([]const u8) {
    return struct {
        const R = AsciiResult([]const u8, AsciiError);
        pub inline fn string(input: []const u8, _: std.mem.Allocator) anyerror!R {
            if (input.len == 0) {
                return R{ .err = .fromKind(input, .String) };
            }

            if (!std.mem.startsWith(u8, input, Str)) {
                return R{ .err = .fromKind(input, .String) };
            }

            return R{ .res = .{ input[Str.len..], input[0..Str.len] } };
        }
    }.string;
}

pub fn AnyOf(comptime Chars: []const u8) AsciiParserFn(u8) {
    return struct {
        const R = AsciiResult(u8, AsciiError);
        pub inline fn anyOf(input: []const u8, _: std.mem.Allocator) anyerror!R {
            if (input.len == 0) {
                return R{ .err = .fromKind(input, .AnyOf) };
            }

            inline for (Chars) |c| {
                if (input[0] == c) {
                    return R{ .res = .{ input[1..], input[0] } };
                }
            }

            return R{ .err = .fromKind(input, .AnyOf) };
        }
    }.anyOf;
}

pub fn NoneOf(comptime Chars: []const u8) AsciiParserFn(u8) {
    return struct {
        const R = AsciiResult(u8, AsciiError);
        pub fn noneOf(input: []const u8, _: std.mem.Allocator) anyerror!R {
            if (input.len == 0) {
                return R{ .err = .fromKind(input, .NoneOf) };
            }

            inline for (Chars) |c| {
                if (input[0] == c) {
                    return R{ .err = .fromKind(input, .NoneOf) };
                }
            }

            return R{ .res = .{ input[1..], input[0] } };
        }
    }.noneOf;
}

pub fn Range(comptime Start: u8, comptime End: u8) AsciiParserFn(u8) {
    return struct {
        const R = AsciiResult(u8, AsciiError);
        pub inline fn range(input: []const u8, _: std.mem.Allocator) anyerror!R {
            if (input.len == 0) {
                return R{ .err = .fromKind(input, .Range) };
            }

            return switch (input[0]) {
                Start...End => R{ .res = .{ input[1..], input[0] } },
                else => R{ .err = .fromKind(input, .Range) },
            };
        }
    }.range;
}

pub inline fn isOct(c: u8) bool {
    return switch (c) {
        '0'...'7' => true,
        else => false,
    };
}

pub inline fn isDigitBase(comptime base: u8) bool {
    return struct {
        pub fn isDigit(c: u8) bool {
            const range_end = '0' + (base - 1);
            return switch (c) {
                '0'...range_end => true,
                else => false,
            };
        }
    }.isDigit;
}

pub const Alpha = Satisfy(std.ascii.isAlphabetic);
pub const AlphaNum = Satisfy(std.ascii.isAlphanumeric);
pub const Ascii = Satisfy(std.ascii.isAscii);
pub const Control = Satisfy(std.ascii.isControl);
pub const Print = Satisfy(std.ascii.isPrint);
pub const Lower = Satisfy(std.ascii.isLower);
pub const Upper = Satisfy(std.ascii.isUpper);
pub const Whitespace = Satisfy(std.ascii.isWhitespace);
pub const DigitDecimal = Satisfy(std.ascii.isDigit);
pub const DigitHexadecimal = Satisfy(std.ascii.isHex);
pub const DigitOctal = Satisfy(isOct);
pub fn Digit(comptime base: u8) type {
    return Satisfy(isDigitBase(base));
}
