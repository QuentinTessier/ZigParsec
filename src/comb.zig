const std = @import("std");
const Parser = @import("parser.zig");

pub fn Many(comptime I: type, comptime T: type, comptime E: type, comptime P: Parser.ParserFn(I, T, E)) Parser.ParserFn(I, []T, E) {
    return struct {
        const R = Parser.Result(I, []T, E);
        pub fn many(input: I, allocator: std.mem.Allocator) anyerror!Parser.Result(I, []T, E) {
            var i = input;
            var array: std.ArrayList(T) = .init(allocator);
            var err: E = undefined;
            while ((try P(i, allocator)).unwrap(&err)) |result| {
                try array.append(result.@"1");
                i = result.@"0";
            }

            return R{ .res = .{ i, try array.toOwnedSlice() } };
        }
    }.many;
}

pub fn Many1(comptime I: type, comptime T: type, comptime E: type, comptime P: Parser.ParserFn(I, T, E)) Parser.ParserFn(I, []T, E) {
    return struct {
        const R = Parser.Result(I, []T, E);
        pub fn many1(input: I, allocator: std.mem.Allocator) anyerror!Parser.Result(I, []T, E) {
            var array: std.ArrayList(T) = .init(allocator);
            var err: E = undefined;
            var i, const value = (try P(input, allocator)).unwrap(&err) orelse {
                return R{ .err = void{} };
            };
            try array.append(value);
            while ((try P(i, allocator)).unwrap(&err)) |result| {
                try array.append(result.@"1");
                i = result.@"0";
            }

            return R{ .res = .{ i, try array.toOwnedSlice() } };
        }
    }.many1;
}

pub fn Choice(comptime I: type, comptime T: type, comptime E: type, comptime P: anytype) Parser.ParserFn(I, T, E) {
    return struct {
        const R = Parser.Result(I, T, E);
        pub fn choice(input: I, allocator: std.mem.Allocator) anyerror!R {
            inline for (P) |parser| {
                switch (try parser(input, allocator)) {
                    .res => |res| return R{ .res = res },
                    .err => {},
                }
            }
            return R{ .err = void{} };
        }
    }.choice;
}
