const std = @import("std");
const Parser = @import("parser.zig");

pub fn Many(comptime I: type, comptime E: type, comptime P: anytype) Parser.ParserFn(I, []Parser.ParsedType(@TypeOf(P)), E) {
    return struct {
        const T: type = Parser.ParsedType(@TypeOf(P));
        const R = Parser.Result(I, []T, E);
        pub fn many(input: I, allocator: std.mem.Allocator) anyerror!R {
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

pub fn Many1(comptime I: type, comptime E: type, comptime P: anytype) Parser.ParserFn(I, []Parser.ParsedType(@TypeOf(P)), E) {
    return struct {
        const T: type = Parser.ParsedType(@TypeOf(P));
        const R = Parser.Result(I, []T, E);
        pub fn many1(input: I, allocator: std.mem.Allocator) anyerror!R {
            var array: std.ArrayList(T) = .init(allocator);
            var err: E = undefined;
            var i, const value = (try P(input, allocator)).unwrap(&err) orelse {
                return R{ .err = .{ input, @src() } };
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

pub fn Choice(comptime I: type, comptime E: type, comptime P: anytype) Parser.ParserFn(I, Parser.ParsedType(@TypeOf(P[0])), E) {
    return struct {
        const T: type = Parser.ParsedType(@TypeOf(P[0]));
        const R = Parser.Result(I, T, E);
        pub fn choice(input: I, allocator: std.mem.Allocator) anyerror!R {
            for (P) |parser| {
                switch (try parser(input, allocator)) {
                    .res => |res| return R{ .res = res },
                    .err => {},
                }
            }
            return R{ .err = .{ input, @src() } };
        }
    }.choice;
}

pub fn SepBy(comptime I: type, comptime E: type, comptime P: anytype, comptime Sep: anytype) Parser.ParserFn(I, []Parser.ParsedType(@TypeOf(P)), E) {
    return struct {
        const SepByStateMachine = enum {
            sep,
            value,
            finished,
        };

        const T: type = Parser.ParsedType(@TypeOf(P));
        const R = Parser.Result(I, []T, E);

        pub fn sepBy(input: I, allocator: std.mem.Allocator) anyerror!R {
            var array: std.ArrayList(T) = .init(allocator);
            var i = input;
            state: switch (SepByStateMachine.value) {
                .value => switch (try P(i, allocator)) {
                    .res => |r| {
                        i = r[0];
                        try array.append(r[1]);
                        continue :state .sep;
                    },
                    .err => continue :state .finished,
                },
                .sep => switch (try Sep(i, allocator)) {
                    .res => |r| {
                        i = r[0];
                        continue :state .value;
                    },
                    .err => continue :state .finished,
                },
                .finished => return R{ .res = .{ i, try array.toOwnedSlice() } },
            }
        }
    }.sepBy;
}
