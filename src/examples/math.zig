const std = @import("std");

const Parser = @import("../Parser.zig");

pub fn singleDigitNumger(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.ZigParsecState) anyerror!Parser.Result(i32) {
    return switch (try Parser.Char.digit(stream, allocator, state)) {
        .Result => |res| Parser.Result(i32).success(@intCast(res.value - 48), res.rest),
        .Error => |err| Parser.Result(i32).failure(err.msg, err.rest),
    };
}

pub fn subExpr(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.ZigParsecState) anyerror!Parser.Result(i32) {
    return Parser.Combinator.between(
        stream,
        allocator,
        state,
        .{ u8, i32, u8 },
        .{ .parser = Parser.Char.symbol, .args = .{'('} },
        expr,
        .{ .parser = Parser.Char.symbol, .args = .{')'} },
    );
}

pub fn expr(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.ZigParsecState) anyerror!Parser.Result(i32) {
    return Parser.Combinator.chainl1(
        stream,
        allocator,
        state,
        i32,
        term,
        *const fn (std.mem.Allocator, i32, i32) anyerror!i32,
        addOp,
    );
}

pub fn term(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.ZigParsecState) anyerror!Parser.Result(i32) {
    return Parser.Combinator.chainl1(
        stream,
        allocator,
        state,
        i32,
        factor,
        *const fn (std.mem.Allocator, i32, i32) anyerror!i32,
        mulOp,
    );
}

pub fn factor(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.ZigParsecState) anyerror!Parser.Result(i32) {
    return Parser.Combinator.choice(stream, allocator, state, i32, &.{
        subExpr,
        singleDigitNumger,
    });
}

pub fn add(_: std.mem.Allocator, lhs: i32, rhs: i32) anyerror!i32 {
    return lhs + rhs;
}

pub fn sub(_: std.mem.Allocator, lhs: i32, rhs: i32) anyerror!i32 {
    return lhs - rhs;
}

pub fn mul(_: std.mem.Allocator, lhs: i32, rhs: i32) anyerror!i32 {
    return lhs * rhs;
}

pub fn div(_: std.mem.Allocator, lhs: i32, rhs: i32) anyerror!i32 {
    return @divFloor(lhs, rhs);
}

pub fn mulOp(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.ZigParsecState) anyerror!Parser.Result(*const fn (std.mem.Allocator, i32, i32) anyerror!i32) {
    switch (try Parser.Combinator.choice(stream, allocator, state, u8, &.{
        .{ .parser = Parser.Char.symbol, .args = .{'*'} },
        .{ .parser = Parser.Char.symbol, .args = .{'/'} },
    })) {
        .Result => |res| {
            switch (res.value) {
                '*' => return Parser.Result(*const fn (std.mem.Allocator, i32, i32) anyerror!i32).success(mul, res.rest),
                '/' => return Parser.Result(*const fn (std.mem.Allocator, i32, i32) anyerror!i32).success(div, res.rest),
                else => unreachable,
            }
        },
        .Error => |err| return Parser.Result(*const fn (std.mem.Allocator, i32, i32) anyerror!i32).failure(err.msg, err.rest),
    }
}

pub fn addOp(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.ZigParsecState) anyerror!Parser.Result(*const fn (std.mem.Allocator, i32, i32) anyerror!i32) {
    switch (try Parser.Combinator.choice(stream, allocator, state, u8, &.{
        .{ .parser = Parser.Char.symbol, .args = .{'+'} },
        .{ .parser = Parser.Char.symbol, .args = .{'-'} },
    })) {
        .Result => |res| {
            switch (res.value) {
                '+' => return Parser.Result(*const fn (std.mem.Allocator, i32, i32) anyerror!i32).success(add, res.rest),
                '-' => return Parser.Result(*const fn (std.mem.Allocator, i32, i32) anyerror!i32).success(sub, res.rest),
                else => unreachable,
            }
        },
        .Error => |err| return Parser.Result(*const fn (std.mem.Allocator, i32, i32) anyerror!i32).failure(err.msg, err.rest),
    }
}
