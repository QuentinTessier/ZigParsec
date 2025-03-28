const std = @import("std");
const Parser = @import("parser.zig");

pub fn Symbol(comptime I: type, comptime T: type, comptime E: type, comptime S: T) Parser.ParserFn(I, T, E) {
    return struct {
        const R = Parser.Result(I, T, E);
        pub fn symbol(input: I, _: std.mem.Allocator) anyerror!Parser.Result(I, T, E) {
            if (input.eof()) {
                return R{ .err = void{} };
            }

            if (input.peek1().? != S) {
                return R{ .err = void{} };
            }

            return R{ .res = .{ input.eat1(), input.peek1().? } };
        }
    }.symbol;
}

pub fn Any(comptime I: type, comptime T: type, comptime E: type) Parser.ParserFn(I, T, E) {
    return struct {
        const R = Parser.Result(I, T, E);
        pub fn any(input: I, _: std.mem.Allocator) anyerror!Parser.Result(I, T, E) {
            if (input.eof()) {
                return R{ .err = void{} };
            }

            return R{ .res = .{ input.eat1(), input.peek1().? } };
        }
    }.any;
}

pub fn AnyOf(comptime I: type, comptime T: type, comptime E: type, comptime Values: []const T) Parser.ParserFn(I, T, E) {
    return struct {
        const R = Parser.Result(I, T, E);
        pub fn anyOf(input: I, _: std.mem.Allocator) anyerror!Parser.Result(I, T, E) {
            if (input.eof()) {
                return R{ .err = void{} };
            }

            for (Values) |c| {
                if (c == input.peek1().?) {
                    return R{ .res = .{ input.eat1(), c } };
                }
            }

            return R{ .err = void{} };
        }
    }.anyOf;
}

pub fn NoneOf(comptime I: type, comptime T: type, comptime E: type, comptime Values: []const T) Parser.ParserFn(I, T, E) {
    return struct {
        const R = Parser.Result(I, T, E);
        pub fn noneOf(input: I, _: std.mem.Allocator) anyerror!Parser.Result(I, T, E) {
            if (input.eof()) {
                return R{ .err = void{} };
            }

            for (Values) |c| {
                if (c == input.peek1().?) {
                    return R{ .err = void{} };
                }
            }

            return R{ .res = .{ input.eat1(), input.peek1().? } };
        }
    }.noneOf;
}

pub fn Range(comptime I: type, comptime T: type, comptime E: type, comptime Values: [2]T) Parser.ParserFn(I, T, E) {
    std.debug.assert(Values[0] < Values[1]);
    return struct {
        const R = Parser.Result(I, T, E);
        pub fn noneOf(input: I, _: std.mem.Allocator) anyerror!Parser.Result(I, T, E) {
            if (input.eof()) {
                return R{ .err = void{} };
            }

            if (input.peek1().? >= Values[0] and input.peek1().? <= Values[1]) {
                return R{ .res = .{ input.eat1(), input.peek1().? } };
            }

            return R{ .err = void{} };
        }
    }.noneOf;
}

pub fn Satisfy(comptime I: type, comptime T: type, comptime E: type, comptime P: fn (T) bool) Parser.ParserFn(I, T, E) {
    return struct {
        const R = Parser.Result(I, T, E);
        pub fn noneOf(input: I, _: std.mem.Allocator) anyerror!Parser.Result(I, T, E) {
            if (input.eof()) {
                return R{ .err = void{} };
            }

            if (P(input.peek1().?)) {
                return R{ .res = .{ input.eat1(), input.peek1().? } };
            }

            return R{ .err = void{} };
        }
    }.noneOf;
}
