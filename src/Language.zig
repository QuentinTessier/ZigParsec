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

pub fn integer(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Int: type) anyerror!Result(Int) {
    switch (try Parser.Char.digit(stream, allocator, state)) {
        .Result => |res| {
            var s = res.rest;
            while (blk: {
                switch (try Parser.Char.digit(s, allocator, state)) {
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
            const buffer = stream.diff(s);
            return Result(Int).success(try std.fmt.parseInt(Int, buffer, 10), s);
        },
        .Error => |err| return Result(Int).failure(err.msg, err.rest),
    }
}

pub fn hexInteger(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Int: type) anyerror!Result(Int) {
    switch (try Parser.Char.hexDigit(stream, allocator, state)) {
        .Result => |res| {
            var s = res.rest;
            while (blk: {
                switch (try Parser.Char.hexDigit(s, allocator, state)) {
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
            const buffer = stream.diff(s);
            return Result(Int).success(try std.fmt.parseInt(Int, buffer, 16), s);
        },
        .Error => |err| return Result(Int).failure(err.msg, err.rest),
    }
}

pub fn octInteger(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Int: type) anyerror!Result(Int) {
    switch (try Parser.Char.octDigit(stream, allocator, state)) {
        .Result => |res| {
            var s = res.rest;
            while (blk: {
                switch (try Parser.Char.octDigit(s, allocator, state)) {
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
            const buffer = stream.diff(s);
            return Result(Int).success(try std.fmt.parseInt(Int, buffer, 8), s);
        },
        .Error => |err| return Result(Int).failure(err.msg, err.rest),
    }
}

inline fn floating1(stream: Stream, allocator: std.mem.Allocator, state: *BaseState) anyerror!Result(void) {
    switch (try Parser.Char.digit(stream, allocator, state)) {
        .Result => |res| {
            var s = res.rest;
            while (blk: {
                switch (try Parser.Char.digit(s, allocator, state)) {
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
            return Result(void).success(void{}, s);
        },
        .Error => |err| return Result(void).failure(err.msg, err.rest),
    }
}

inline fn floating2(stream: Stream, allocator: std.mem.Allocator, state: *BaseState) anyerror!Result(void) {
    return switch (try Parser.Char.symbol(stream, allocator, state, '.')) {
        .Result => |res| floating1(res.rest, allocator, state),
        .Error => |err| blk: {
            err.msg.deinit();
            break :blk Result(void).success(void{}, stream);
        },
    };
}

inline fn floating3(stream: Stream, allocator: std.mem.Allocator, state: *BaseState) anyerror!Result(void) {
    return switch (try Parser.Char.symbol(stream, allocator, state, 'e')) {
        .Result => |res| switch (try Parser.Char.symbol(res.rest, allocator, state, '-')) {
            .Result => |res1| floating1(res1.rest, allocator, state),
            .Error => |err| blk: {
                err.msg.deinit();
                break :blk floating1(err.rest, allocator, state);
            },
        },
        .Error => |err| blk: {
            err.msg.deinit();
            break :blk Result(void).success(void{}, stream);
        },
    };
}

pub fn floating(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Float: type) anyerror!Result(Float) {
    switch (try floating1(stream, allocator, state)) {
        .Result => |res| {
            var s = res.rest;
            switch (try floating2(s, allocator, state)) {
                .Result => |res1| s = res1.rest,
                .Error => unreachable,
            }
            switch (try floating3(s, allocator, state)) {
                .Result => |res2| s = res2.rest,
                .Error => unreachable,
            }

            const buffer = stream.diff(s);
            return Result(Float).success(try std.fmt.parseFloat(Float, buffer), s);
        },
        .Error => |err| return Result(Float).failure(err.msg, err.rest),
    }
}
