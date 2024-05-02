const std = @import("std");
const Parser = @import("Parser.zig");
const Stream = @import("Stream.zig");
const ZigParsecState = @import("UserState.zig").ZigParsecState;
const Result = @import("Result.zig").Result;
const runParser = Parser.runParser;

pub fn identifier(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result([]u8) {
    var array: std.ArrayList(u8) = std.ArrayList(u8).init(allocator);
    var s = stream;
    s.eatWhitespace = false;
    switch (try Parser.Combinator.choice(s, allocator, state, u8, &.{
        Parser.Char.alpha,
        .{ .parser = Parser.Char.symbol, .args = .{'_'} },
    })) {
        .Result => |res| {
            try array.append(res.value);
            switch (try Parser.Combinator.many(res.rest, allocator, state, u8, Parser.Char.alphaNum)) {
                .Result => |res2| {
                    if (res2.value.len > 0) {
                        try array.appendSlice(res2.value);
                        allocator.free(res2.value);
                    }
                    return Result([]u8).success(try array.toOwnedSlice(), res2.rest);
                },
                .Error => unreachable,
            }
        },
        .Error => |err| return Result([]u8).failure(err.msg, err.rest),
    }
}

pub fn integerString(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result([]u8) {
    return Parser.Combinator.many1(stream, allocator, state, u8, Parser.Char.digit);
}

pub fn reserved(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, name: []const u8) anyerror!Result([]const u8) {
    return Parser.Combinator.notFollowedBy(stream, allocator, state, []const u8, .{ .parser = Parser.Char.string, .args = .{name} }, u8, Parser.Char.alphaNum);
}

pub fn operator(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, symbol: []const u8, notFollowed: ?[]const u8) anyerror!Result([]const u8) {
    if (notFollowed) |followed| {
        switch (try Parser.Char.spaces(stream, allocator, state)) {
            .Result => |stripped| {
                return Parser.Combinator.notFollowedBy(
                    stripped.rest,
                    allocator,
                    state,
                    []const u8,
                    .{ Parser.Char.string, .{symbol} },
                    u8,
                    .{ Parser.Char.oneOf, .{followed} },
                );
            },
            .Error => unreachable,
        }
    } else {
        switch (try Parser.Char.spaces(stream, allocator, state)) {
            .Result => |stripped| {
                return Parser.Char.string(stripped.rest, allocator, state, symbol);
            },
            .Error => unreachable,
        }
    }
}

pub inline fn eatWhitespaceBefore(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, comptime T: type, p: anytype) anyerror!Result(T) {
    return switch (try Parser.Char.spaces(stream, allocator, state)) {
        .Result => |res| runParser(res.rest, allocator, state, T, p),
        .Error => |err| Result(T).failure(err.msg, err.rest),
    };
}
