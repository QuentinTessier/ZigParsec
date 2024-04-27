const std = @import("std");
const Parser = @import("Parser.zig");
const Stream = @import("Stream.zig");
const ZigParsecState = @import("UserState.zig").ZigParsecState;
const Result = @import("Result.zig").Result;

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
