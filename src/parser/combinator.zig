const std = @import("std");
const parser = @import("parser.zig");
const Result = @import("result.zig").Result;

pub fn Combinator(comptime S: type, comptime E: type) type {
    return struct {
        pub fn Alt(comptime Ps: anytype) blk: {
            const PResult = parser.ParserResult(@TypeOf(Ps[0]));
            const ValueType = PResult.ValueType;
            break :blk parser.Parser(S, ValueType, E);
        } {
            const R = parser.ParserResult(@TypeOf(Ps[0]));

            return struct {
                pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
                    const checkpoint = stream.checkpoint();
                    var last_err: ?E = null;

                    inline for (Ps) |p| {
                        const res = try p(stream, allocator);
                        switch (res) {
                            .result => return res,
                            .@"error" => |err| switch (err.value) {
                                .fatal => return res,
                                .backtrack => |inner| {
                                    if (last_err != null) {
                                        _ = last_err.?.@"or"(allocator, &inner);
                                    } else last_err = inner;
                                },
                            },
                        }
                    }

                    _ = last_err.?.append(stream, checkpoint);
                    return R.failure(.{
                        .backtrack = last_err.?,
                    }, stream);
                }
            }.inline_parser;
        }

        pub fn AltUnion(comptime U: type, comptime Ps: anytype) type {
            const R = parser.ParserResult(U);

            return struct {
                pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
                    const checkpoint = stream.checkpoint();
                    var last_err: ?E = null;

                    inline for (Ps) |fp| {
                        const field = fp[0];
                        const p = fp[1];
                        const res = try p(stream, allocator);
                        switch (res) {
                            .result => return R.success(@unionInit(U, @tagName(field), res.value)),
                            .@"error" => |err| switch (err.value) {
                                .fatal => return res,
                                .backtrack => |inner| {
                                    if (last_err != null) {
                                        _ = last_err.?.@"or"(allocator, &inner);
                                    } else last_err = inner;
                                },
                            },
                        }
                    }

                    _ = last_err.?.append(stream, checkpoint);
                    return R.failure(.{
                        .backtrack = last_err.?,
                    }, stream);
                }
            }.inline_parser;
        }

        pub fn Many(comptime P: anytype) blk: {
            const PResult = parser.ParserResult(@TypeOf(P));
            const ValueType = PResult.ValueType;

            break :blk parser.Parser(S, []ValueType, E);
        } {
            const PResult = parser.ParserResult(@TypeOf(P));
            const ValueType: type = PResult.ValueType;
            const R = Result(S, []ValueType, E);

            return struct {
                pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
                    var values: std.array_list.Aligned(ValueType, null) = .empty;
                    var s = stream;

                    while (true) {
                        const r = try P(s, allocator);
                        switch (r) {
                            .result => |res| {
                                s = res.rest;
                                try values.append(allocator, res.value);
                            },
                            .@"error" => |err| {
                                if (err.value == .backtrack) break else return R.failure(err.value, err.rest);
                            },
                        }
                    }
                    return R.success(try values.toOwnedSlice(allocator), s);
                }
            }.inline_parser;
        }

        pub fn Many1(comptime P: anytype) blk: {
            const PResult = parser.ParserResult(@TypeOf(P));
            const ValueType = PResult.ValueType;

            break :blk parser.Parser(S, []ValueType, E);
        } {
            const PResult = parser.ParserResult(@TypeOf(P));
            const ValueType: type = PResult.ValueType;
            const R = Result(S, []ValueType, E);

            return struct {
                pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
                    var values: std.array_list.Aligned(ValueType, null) = .empty;
                    var s = stream;

                    const first = try P(s, allocator);
                    switch (first) {
                        .result => |res| {
                            s = res.rest;
                            try values.append(allocator, res.value);
                        },
                        .@"error" => |err| return R.failure(err.value, err.rest),
                    }
                    while (true) {
                        const r = try P(s, allocator);
                        switch (r) {
                            .result => |res| {
                                s = res.rest;
                                try values.append(allocator, res.value);
                            },
                            .@"error" => |err| {
                                if (err.value == .backtrack) break else return R.failure(err.value, err.rest);
                            },
                        }
                    }
                    return R.success(try values.toOwnedSlice(allocator), s);
                }
            }.inline_parser;
        }

        pub fn Between(comptime open: anytype, comptime close: anytype, comptime P: anytype) blk: {
            const PResult = parser.ParserResult(@TypeOf(P));
            const ValueType = PResult.ValueType;

            break :blk parser.Parser(S, ValueType, E);
        } {
            const PResult = parser.ParserResult(@TypeOf(P));
            const ValueType: type = PResult.ValueType;
            const R = Result(S, ValueType, E);

            return struct {
                pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
                    const open_res = try open(stream, allocator);
                    switch (open_res) {
                        .result => |r0| {
                            const p_res = try P(r0.rest, allocator);
                            switch (p_res) {
                                .result => |r1| {
                                    const close_res = try close(r1.rest, allocator);
                                    switch (close_res) {
                                        .result => |r2| return R.success(r1.value, r2.rest),
                                        .@"error" => |e| return R.failure(e.value, e.rest),
                                    }
                                },
                                .@"error" => |e| return R.failure(e.value, e.rest),
                            }
                        },
                        .@"error" => |e| return R.failure(e.value, e.rest),
                    }
                }
            }.inline_parser;
        }

        pub fn SepBy(comptime Separator: anytype, comptime P: anytype) blk: {
            const PResult = parser.ParserResult(@TypeOf(P));
            const ValueType: type = PResult.ValueType;

            break :blk parser.Parser(S, []ValueType, E);
        } {
            const PResult = parser.ParserResult(@TypeOf(P));
            const ValueType: type = PResult.ValueType;
            const R = Result(S, []ValueType, E);

            return struct {
                pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
                    var s: S = stream;
                    var values: std.array_list.Aligned(ValueType, null) = .empty;
                    const first_value = try P(stream, allocator);
                    switch (first_value) {
                        .result => |res| {
                            try values.append(allocator, res.value);
                            s = res.rest;
                        },
                        .@"error" => return R.success(&.{}, stream),
                    }

                    while (blk: {
                        const sep = try Separator(s, allocator);
                        switch (sep) {
                            .result => |res| {
                                s = res.rest;
                                break :blk true;
                            },
                            .@"error" => break :blk false,
                        }
                    }) {
                        const value = try P(s, allocator);
                        switch (value) {
                            .result => |res| {
                                try values.append(allocator, res.value);
                                s = res.rest;
                            },
                            .@"error" => |e| return R.failure(e.value, e.rest),
                        }
                    }
                    return R.success(try values.toOwnedSlice(allocator), s);
                }
            }.inline_parser;
        }

        pub fn SepBy1(comptime Separator: anytype, comptime P: anytype) blk: {
            const PResult = parser.ParserResult(@TypeOf(P));
            const ValueType: type = PResult.ValueType;

            break :blk parser.Parser(S, []ValueType, E);
        } {
            const PResult = parser.ParserResult(@TypeOf(P));
            const ValueType: type = PResult.ValueType;
            const R = Result(S, []ValueType, E);

            return struct {
                pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
                    var s: S = stream;
                    var values: std.array_list.Aligned(ValueType, null) = .empty;
                    const first_value = try P(stream, allocator);
                    switch (first_value) {
                        .result => |res| {
                            try values.append(allocator, res.value);
                            s = res.rest;
                        },
                        .@"error" => |e| return R.failure(e.value, e.rest),
                    }

                    while (blk: {
                        const sep = try Separator(s, allocator);
                        switch (sep) {
                            .result => |res| {
                                s = res.rest;
                                break :blk true;
                            },
                            .@"error" => break :blk false,
                        }
                    }) {
                        const value = try P(s, allocator);
                        switch (value) {
                            .result => |res| {
                                try values.append(allocator, res.value);
                                s = res.rest;
                            },
                            .@"error" => |e| return R.failure(e.value, e.rest),
                        }
                    }
                    return R.success(try values.toOwnedSlice(allocator), s);
                }
            }.inline_parser;
        }
    };
}
