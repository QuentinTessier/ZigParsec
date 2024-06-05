const std = @import("std");
const Stream = @import("Stream.zig");
const BaseState = @import("UserState.zig").BaseState;

const Result = @import("Result.zig").Result;

// Tries to match 'c'
pub fn symbol(stream: Stream, allocator: std.mem.Allocator, _: *BaseState, c: u8) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    if (peeked[0] == c) {
        return Result(u8).success(c, stream.eat(1));
    }

    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected '{c}' found '{c}'", .{ stream, c, peeked[0] });
    return Result(u8).failure(error_msg, stream);
}

// Match any character
pub fn any(stream: Stream, allocator: std.mem.Allocator, _: *BaseState) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    return Result(u8).success(stream.peek(1)[0], stream.eat(1));
}

// Match one of the character given in the array
pub fn oneOf(stream: Stream, allocator: std.mem.Allocator, _: *BaseState, x: []const u8) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    for (x) |c| {
        if (peeked[0] == c) {
            return Result(u8).success(c, stream.eat(1));
        }
    }

    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected any of \"{s}\" found '{c}'", .{ stream, x, peeked[0] });
    return Result(u8).failure(error_msg, stream);
}

// Match none of the character given in the array
pub fn noneOf(stream: Stream, allocator: std.mem.Allocator, _: *BaseState, x: []const u8) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    for (x) |c| {
        if (peeked[0] == c) {
            var error_msg = std.ArrayList(u8).init(allocator);
            var writer = error_msg.writer();
            try writer.print("{}: Expected none of \"{s}\" found '{c}'", .{ stream, x, peeked[0] });
            return Result(u8).failure(error_msg, stream);
        }
    }

    return Result(u8).success(peeked[0], stream.eat(1));
}

// Match a character between l and h
pub fn range(stream: Stream, allocator: std.mem.Allocator, _: *BaseState, l: u8, h: u8) anyerror!Result(u8) {
    std.debug.assert(l < h);
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    if (peeked[0] >= l and peeked[0] <= h) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }
    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected character between '{c}' and '{c}' found '{c}'", .{ stream, l, h, peeked[0] });
    return Result(u8).failure(error_msg, stream);
}

// Match a uppercase letter
pub fn upper(stream: Stream, allocator: std.mem.Allocator, _: *BaseState) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isUpper(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected an uppercase letter, found {c}", .{ stream, peeked[0] });
    return Result(u8).failure(error_msg, stream);
}

// Match a lowercase letter
pub fn lower(stream: Stream, allocator: std.mem.Allocator, _: *BaseState) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isLower(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected an lowercase letter, found {c}", .{ stream, peeked[0] });
    return Result(u8).failure(error_msg, stream);
}

// Match a upper or lowercase letter
pub fn alpha(stream: Stream, allocator: std.mem.Allocator, _: *BaseState) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isAlphabetic(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected an alphabetic character, found {c}", .{ stream, peeked[0] });
    return Result(u8).failure(error_msg, stream);
}

// Match a upper or lowercase letter or a digit
pub fn alphaNum(stream: Stream, allocator: std.mem.Allocator, _: *BaseState) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isAlphanumeric(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected an alphabetic numeric character, found {c}", .{ stream, peeked[0] });
    return Result(u8).failure(error_msg, stream);
}

// Match a digit
pub fn digit(stream: Stream, allocator: std.mem.Allocator, _: *BaseState) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isDigit(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected a digit, found {c}", .{ stream, peeked[0] });
    return Result(u8).failure(error_msg, stream);
}

// Match a octal digit
pub fn octDigit(stream: Stream, allocator: std.mem.Allocator, _: *BaseState) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    if (blk: {
        break :blk switch (peeked[0]) {
            '0'...'7' => true,
            else => false,
        };
    }) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected a octal digit, found {c}", .{ stream, peeked[0] });
    return Result(u8).failure(error_msg, stream);
}

// Match a hexadecimal digit
pub fn hexDigit(stream: Stream, allocator: std.mem.Allocator, _: *BaseState) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isHex(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected a hexadecimal digit, found {c}", .{ stream, peeked[0] });
    return Result(u8).failure(error_msg, stream);
}

// Match a character statisfying the given function
pub fn satisfy(stream: Stream, allocator: std.mem.Allocator, _: *BaseState, fnc: *const fn (u8) bool) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    if (fnc(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected a character validating predicate {*}, found {c}", .{ stream, fnc, peeked[0] });
    return Result(u8).failure(error_msg, stream);
}

// Match a whitespace
pub fn space(stream: Stream, allocator: std.mem.Allocator, _: *BaseState) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result(u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isWhitespace(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected whitespace character, found {c}", .{ stream, peeked[0] });
    return Result(u8).failure(error_msg, stream);
}

// Match multiple whitespaces
pub fn spaces(stream: Stream, _: std.mem.Allocator, _: *BaseState) anyerror!Result(void) {
    if (stream.isEOF()) return Result(void).success(void{}, stream);
    const start = stream.currentLocation.index;
    var end = start;

    while (end < stream.data.len and std.ascii.isWhitespace(stream.data[end])) : (end += 1) {}

    return Result(void).success(void{}, stream.eat(end - start));
}

// Match a given string
pub fn string(stream: Stream, allocator: std.mem.Allocator, _: *BaseState, str: []const u8) anyerror!Result([]const u8) {
    if (stream.isEOF()) {
        var error_msg = std.ArrayList(u8).init(allocator);
        var writer = error_msg.writer();
        try writer.print("{}: Unexpected EndOfStream", .{stream});
        return Result([]const u8).failure(error_msg, stream);
    }

    const peeked = stream.peek(str.len);
    if (peeked.len == str.len and std.mem.eql(u8, peeked, str)) {
        return Result([]const u8).success(str, stream.eat(str.len));
    }
    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected a word '{s}', found '{s}'", .{ stream, str, peeked });
    return Result([]const u8).failure(error_msg, stream);
}
