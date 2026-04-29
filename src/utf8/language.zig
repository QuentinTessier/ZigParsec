const std = @import("std");

const Stream = @import("stream.zig").Stream;
const ParseError = @import("error.zig").ParseError;
const Utf8Parser = @import("parser.zig").Utf8Parser;

const Result = @import("../parser/result.zig").Result;
const Error = @import("../parser/error.zig").Error;

const Utf8Char = @import("char.zig");
const Utf8Combinator = @import("../parser/combinator.zig").Combinator(Stream, ParseError);

const ParserResult = @import("../parser/parser.zig").ParserResult;

fn identifier_first_character_predicate(c: u8) bool {
    return c == '_' or std.ascii.isAlphabetic(c);
}

fn identifier_character_predicate(c: u8) bool {
    return c == '_' or std.ascii.isAlphanumeric(c);
}

const identifier_first_character = Utf8Char.Satisfy(identifier_first_character_predicate, "`_` or [A ... Z, a ... z]");
const identifier_character = Utf8Char.Satisfy(identifier_character_predicate, "`_` or [A ... Z, a ... z, 0 ... 9]");

pub fn _identifier_rest(stream: Stream, allocator: std.mem.Allocator, start: Stream.Checkpoint) anyerror!Result(Stream, []const u8, ParseError) {
    var s = stream;

    while (run: {
        const res = try identifier_character(s, allocator);
        switch (res) {
            .result => |r| {
                s = r.rest;
                break :run true;
            },
            .@"error" => break :run false,
        }
    }) {}

    return Result(Stream, []const u8, ParseError).success(s.slice(start), s);
}

pub fn _identifier(stream: Stream, allocator: std.mem.Allocator) anyerror!Result(Stream, []const u8, ParseError) {
    const checkpoint = stream.checkpoint();
    const first = try identifier_first_character(stream, allocator);
    return switch (first) {
        .result => |r0| _identifier_rest(r0.rest, allocator, checkpoint),
        .@"error" => |e| Result(Stream, []const u8, ParseError).failure(e.value, e.rest),
    };
}

pub fn Identifier(comptime Reserved: []const []const u8) Utf8Parser([]const u8) {
    return struct {
        const R = Result(Stream, []const u8, ParseError);
        pub fn inline_parser(stream: Stream, allocator: std.mem.Allocator) anyerror!R {
            const checkpoint = stream.checkpoint();
            const identifier = try _identifier(stream, allocator);
            switch (identifier) {
                .result => |res| {
                    inline for (Reserved) |keyword| {
                        if (std.mem.eql(u8, res.value, keyword)) {
                            var err: ParseError = .empty;
                            _ = err.unexpected(.{ .unexpected_message = "reserved keyword `" ++ keyword ++ "`" })
                                .append(stream.consume(1), checkpoint);
                            return R.failure(.{ .backtrack = err }, stream);
                        } else {
                            return identifier;
                        }
                    }
                },
                .@"error" => return identifier,
            }
        }
    }.inline_parser;
}

pub fn whitespace_before(comptime P: anytype) blk: {
    const PResult = ParserResult(@TypeOf(P));
    const ValueType = PResult.ValueType;

    break :blk Utf8Parser(ValueType);
} {
    return struct {
        const PResult = ParserResult(@TypeOf(P));
        const ValueType: type = PResult.ValueType;
        const R = Result(Stream, ValueType, ParseError);

        pub fn inline_parser(stream: Stream, allocator: std.mem.Allocator) anyerror!R {
            const s = (try Utf8Char.spaces(stream, allocator)).stream();
            return P(s, allocator);
        }
    }.inline_parser;
}
