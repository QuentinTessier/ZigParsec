const std = @import("std");
const Parser = @import("Parser.zig");
const Stream = @import("Stream.zig");
const BaseState = @import("UserState.zig").BaseState;
const Result = @import("Result.zig").Result;
const runParser = Parser.runParser;

fn identifierChar(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime isFirstChar: bool) anyerror!Result(u8) {
    return Parser.Combinator.choice(stream, allocator, state, u8, if (isFirstChar) .{
        Parser.Char.alpha,
        .{ Parser.Char.symbol, .{'_'} },
    } else .{
        Parser.Char.alphaNum,
        .{ Parser.Char.symbol, .{'_'} },
    });
}

pub fn identifier(stream: Stream, allocator: std.mem.Allocator, state: *BaseState) anyerror!Result([]u8) {
    switch (try identifierChar(stream, allocator, state, true)) {
        .Result => |res| {
            var s = res.rest;
            while (blk: {
                switch (try identifierChar(s, allocator, state, false)) {
                    .Result => |res1| {
                        s = res1.rest;
                        break :blk true;
                    },
                    .Error => |err| {
                        err.msg.deinit();
                        break :blk false;
                    },
                }
            }) {}
            return Result([]u8).success(try allocator.dupe(u8, stream.diff(s)), s);
        },
        .Error => |err| return Result([]u8).failure(err.msg, err.rest),
    }
}

pub fn integerString(stream: Stream, allocator: std.mem.Allocator, state: *BaseState) anyerror!Result([]u8) {
    return Parser.Combinator.many1(stream, allocator, state, u8, Parser.Char.digit);
}

pub fn reserved(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, name: []const u8) anyerror!Result([]const u8) {
    return Parser.Combinator.notFollowedBy(stream, allocator, state, []const u8, .{ .parser = Parser.Char.string, .args = .{name} }, u8, Parser.Char.alphaNum);
}

inline fn operator1(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, symbol: []const u8) anyerror!Result([]const u8) {
    return eatWhitespaceBefore(stream, allocator, state, []const u8, .{ Parser.Char.string, .{symbol} });
}

inline fn operator2(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, symbol: []const u8, notFollowed: []const u8) anyerror!Result([]const u8) {
    return eatWhitespaceBefore(stream, allocator, state, []const u8, .{
        Parser.Combinator.notFollowedBy, .{
            []const u8,
            .{ Parser.Char.string, .{symbol} },
            u8,
            .{ Parser.Char.oneOf, .{notFollowed} },
        },
    });
}

pub fn operator(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, symbol: []const u8, notFollowed: ?[]const u8) anyerror!Result([]const u8) {
    if (notFollowed) |followed| {
        return operator2(stream, allocator, state, symbol, followed);
    } else {
        return operator1(stream, allocator, state, symbol);
    }
}

pub inline fn eatWhitespaceBefore(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime T: type, p: anytype) anyerror!Result(T) {
    return switch (try Parser.Char.spaces(stream, allocator, state)) {
        .Result => |res| runParser(res.rest, allocator, state, T, p),
        .Error => |err| Result(T).failure(err.msg, err.rest),
    };
}
