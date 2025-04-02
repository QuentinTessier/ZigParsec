const std = @import("std");
const Parser = @import("parser.zig");

pub fn Comb(comptime I: type, comptime E: type) type {
    return struct {
        pub fn Many(comptime P: anytype) Parser.ParserFn(I, []Parser.ParsedType(@TypeOf(P)), E) {
            return struct {
                const T: type = Parser.ParsedType(@TypeOf(P));
                const R = Parser.Result(I, []T, E);
                pub fn many(input: I, allocator: std.mem.Allocator) anyerror!R {
                    var i = input;
                    var array: std.ArrayList(T) = .init(allocator);
                    errdefer array.deinit();

                    var err: E = undefined;
                    while ((try P(i, allocator)).unwrap(&err)) |result| {
                        try array.append(result.@"1");
                        i = result.@"0";
                    }

                    return R{ .res = .{ i, try array.toOwnedSlice() } };
                }
            }.many;
        }

        pub fn Many1(comptime P: anytype) Parser.ParserFn(I, []Parser.ParsedType(@TypeOf(P)), E) {
            return struct {
                const T: type = Parser.ParsedType(@TypeOf(P));
                const R = Parser.Result(I, []T, E);
                pub fn many1(input: I, allocator: std.mem.Allocator) anyerror!R {
                    var array: std.ArrayList(T) = .init(allocator);
                    errdefer array.deinit();

                    var err: E = undefined;
                    var i, const value = (try P(input, allocator)).unwrap(&err) orelse {
                        return R{ .err = .fromKind(input, .Many1) };
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

        pub fn Choice(comptime P: anytype) Parser.ParserFn(I, Parser.ParsedType(@TypeOf(P[0])), E) {
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
                    return R{ .err = .fromKind(input, .Choice) };
                }
            }.choice;
        }

        pub fn SepBy(comptime P: anytype, comptime Sep: anytype) Parser.ParserFn(I, []Parser.ParsedType(@TypeOf(P)), E) {
            return struct {
                const SepByStateMachine = enum {
                    sep,
                    first_value,
                    value,
                    finished,
                };

                const T: type = Parser.ParsedType(@TypeOf(P));
                const R = Parser.Result(I, []T, E);

                pub fn sepBy(input: I, allocator: std.mem.Allocator) anyerror!R {
                    var array: std.ArrayList(T) = .init(allocator);
                    errdefer array.deinit();

                    var i = input;
                    state: switch (SepByStateMachine.first_value) {
                        .first_value => switch (try P(i, allocator)) {
                            .res => |r| {
                                i = r[0];
                                try array.append(r[1]);
                                continue :state .sep;
                            },
                            .err => continue :state .finished,
                        },
                        .value => switch (try P(i, allocator)) {
                            .res => |r| {
                                i = r[0];
                                try array.append(r[1]);
                                continue :state .sep;
                            },
                            .err => {
                                array.deinit();
                                return R{ .err = .fromKind(input, .SepBy) };
                            },
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

        pub fn Between(comptime Open: anytype, comptime Value: anytype, comptime Close: anytype) Parser.ParserFn(I, Parser.ParsedType(@TypeOf(Value)), E) {
            return struct {
                const T: type = Parser.ParsedType(@TypeOf(Value));
                const R = Parser.Result(I, T, E);

                pub fn between(input: I, allocator: std.mem.Allocator) anyerror!R {
                    var err: E = undefined;
                    const input1, _ = (try Open(input, allocator)).unwrap(&err) orelse {
                        return R{ .err = .fromKind(input, .Between) };
                    };
                    const input2, const value = (try Value(input1, allocator)).unwrap(&err) orelse {
                        return R{ .err = .fromKind(input, .Between) };
                    };
                    const input3, _ = (try Close(input2, allocator)).unwrap(&err) orelse {
                        return R{ .err = .fromKind(input, .Between) };
                    };

                    return R{ .res = .{ input3, value } };
                }
            }.between;
        }
    };
}
