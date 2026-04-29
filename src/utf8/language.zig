const std = @import("std");

const Stream = @import("stream.zig").Stream;
const ParseError = @import("error.zig").ParseError;
const Utf8Parser = @import("parser.zig").Utf8Parser;

const Result = @import("../parser/result.zig").Result;
const Error = @import("../parser/error.zig").Error;

const Utf8Char = @import("char.zig");
const Utf8Combinator = @import("../parser/combinator.zig").Combinator(Stream, ParseError);

fn identifier_first_character_predicate(c: u8) bool {
    return c == '_' or std.ascii.isAlphabetic(c);
}

fn identifier_character_predicate(c: u8) bool {
    std.log.debug("{c} => {}", .{ c, c == '_' or std.ascii.isAlphanumeric(c) });
    return c == '_' or std.ascii.isAlphanumeric(c);
}

const identifier_first_character = Utf8Char.Satisfy(identifier_first_character_predicate, "`_` or [A ... Z, a ... z]");
const identifier_character = Utf8Char.Satisfy(identifier_character_predicate, "`_` or [A ... Z, a ... z, 0 ... 9]");
const many_identifier_character = Utf8Combinator.Many(identifier_character);

pub fn _identifier(stream: Stream, allocator: std.mem.Allocator) anyerror!Result(Stream, []const u8, ParseError) {
    const checkpoint = stream.checkpoint();
    const first = try identifier_first_character(stream, allocator);
    switch (first) {
        .result => |r0| {
            const remaining = try many_identifier_character(r0.rest, allocator);
            switch (remaining) {
                .result => |r1| {
                    return Result(Stream, []const u8, ParseError).success(r1.rest.slice(checkpoint), r1.rest);
                },
                .@"error" => unreachable,
            }
        },
        .@"error" => |e| return Result(Stream, []const u8, ParseError).failure(e.value, e.rest),
    }
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
