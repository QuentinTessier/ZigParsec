const std = @import("std");

const Stream = @import("stream.zig").Stream;
const ParseError = @import("error.zig").ParseError;
const Utf8Parser = @import("parser.zig").Utf8Parser;

const Result = @import("../parser/result.zig").Result;
const Error = @import("../parser/error.zig").Error;

pub fn Many(comptime V: type, comptime P: Utf8Parser(V)) Utf8Parser([]V) {
    return struct {
        const R = Result(Stream, []V, Error(ParseError));

        pub fn inline_parser(stream: Stream, allocator: std.mem.Allocator) anyerror!R {
            var s: Stream = stream;
            var values: std.array_list.Aligned(V, null) = .empty;
            while (true) {
                const res = try P(s, allocator);
                switch (res) {
                    .result => |r| {
                        try values.append(allocator, r.value);
                        s = r.rest;
                    },
                    .@"error" => break,
                }
            }

            return R.success(try values.toOwnedSlice(allocator), s);
        }
    }.inline_parser;
}

pub fn Alt(comptime V: type, comptime Ps: []const Utf8Parser(V)) Utf8Parser(V) {
    return struct {
        const R = Result(Stream, V, Error(ParseError));

        pub fn inline_parser(stream: Stream, allocator: std.mem.Allocator) anyerror!R {
            const checkpoint = stream.checkpoint();
            var last_err: ?ParseError = null;

            inline for (Ps) |P| {
                const res = try P(stream, allocator);
                switch (res) {
                    .result => return res,
                    .@"error" => |e| switch (e.value) {
                        .fatal => return res,
                        .backtrack => |inner| {
                            if (last_err != null) {
                                _ = last_err.?.@"or"(allocator, &inner);
                            } else {
                                last_err = inner;
                            }
                        },
                    },
                }
            }

            _ = last_err.?.append(stream, checkpoint);
            return R.failure(.{ .backtrack = last_err.? }, stream);
        }
    }.inline_parser;
}
