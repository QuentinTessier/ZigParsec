const std = @import("std");
const parser = @import("parser.zig");
const Result = @import("result.zig").Result;

pub fn Combinator(comptime S: type, comptime E: type) type {
    return struct {
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
