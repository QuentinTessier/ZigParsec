const std = @import("std");
const Parser = @import("parser.zig");

pub fn Symbol(comptime I: type, comptime E: type, comptime s: anytype) Parser.ParserFn(I, @TypeOf(s), E) {
    return struct {
        const R = Parser.Result(I, @TypeOf(s), E);
        pub fn symbol(input: I, _: std.mem.Allocator) anyerror!R {
            if (input.len == 0) {
                return R{ .err = .{ input, @src() } };
            }

            if (input[0] != s) {
                return R{ .err = .{ input, @src() } };
            }

            return R{ .res = .{ input[1..], input[0] } };
        }
    }.symbol;
}

pub fn Any(comptime I: type, comptime T: type, comptime E: type) Parser.ParserFn(I, T, E) {
    return struct {
        const R = Parser.Result(I, T, E);
        pub fn any(input: I, _: std.mem.Allocator) anyerror!Parser.Result(I, T, E) {
            if (input.len == 0) {
                return R{ .err = .{ input, @src() } };
            }

            return R{ .res = .{ input[1..], input[0] } };
        }
    }.any;
}

pub fn AnyOf(comptime I: type, comptime E: type, comptime Values: anytype) Parser.ParserFn(I, Parser.ParsedType(@TypeOf(Values[0])), E) {
    return struct {
        const R = Parser.Result(I, Parser.ParsedType(@TypeOf(Values[0])), E);
        pub fn anyOf(input: I, _: std.mem.Allocator) anyerror!R {
            if (input.len == 0) {
                return R{ .err = .{ input, @src() } };
            }

            inline for (Values) |c| {
                if (c == input[0]) {
                    return R{ .res = .{ input[1..], c } };
                }
            }

            return R{ .err = .{ input, @src() } };
        }
    }.anyOf;
}

pub fn NoneOf(comptime I: type, comptime E: type, comptime Values: anytype) Parser.ParserFn(I, Parser.ParsedType(@TypeOf(Values[0])), E) {
    return struct {
        const R = Parser.Result(I, Parser.ParsedType(@TypeOf(Values[0])), E);
        pub fn noneOf(input: I, _: std.mem.Allocator) anyerror!R {
            if (input.len == 0) {
                return R{ .err = .{ input, @src() } };
            }

            for (Values) |c| {
                if (c == input[0]) {
                    return R{ .err = .{ input, @src() } };
                }
            }

            return R{ .res = .{ input[1..], input[0] } };
        }
    }.noneOf;
}

pub fn Range(comptime I: type, comptime E: type, comptime Values: anytype) Parser.ParserFn(I, @TypeOf(Values[0]), E) {
    std.debug.assert(Values[0] < Values[1]);
    return struct {
        const R = Parser.Result(I, @TypeOf(Values[0]), E);
        pub fn noneOf(input: I, _: std.mem.Allocator) anyerror!R {
            if (input.len == 0) {
                return R{ .err = .{ input, @src() } };
            }

            if (input[0] >= Values[0] and input[0] <= Values[1]) {
                return R{ .res = .{ input[1..], input[0] } };
            }

            return R{ .err = .{ input, @src() } };
        }
    }.noneOf;
}

// TODO: Get the type of the argument of the predicate
pub fn Satisfy(comptime I: type, comptime T: type, comptime E: type, comptime P: fn (T) bool) Parser.ParserFn(I, T, E) {
    return struct {
        const R = Parser.Result(I, T, E);
        pub fn noneOf(input: I, _: std.mem.Allocator) anyerror!R {
            if (input.len == 0) {
                return R{ .err = .{ input, @src() } };
            }

            if (P(input[0])) {
                return R{ .res = .{ input[1..], input[0] } };
            }

            return R{ .err = .{ input, @src() } };
        }
    }.noneOf;
}
