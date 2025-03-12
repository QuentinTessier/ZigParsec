const std = @import("std");
const Stream = @import("Stream.zig");
const State = @import("UserState.zig").State;
const ParseError = @import("./error/ParseError.zig");

const Result = @import("Result.zig").Result;

// Tries to match 'c'
pub fn symbol(stream: Stream, allocator: std.mem.Allocator, _: State, c: u8) anyerror!Result(u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedToken(allocator, "{c}", .{c});
        try err.withContext(allocator, "symbol");
        return Result(u8).failure(err, stream);
    }

    const peeked = stream.peek(1);
    if (peeked[0] == c) {
        return Result(u8).success(c, stream.eat(1));
    }

    try err.expectedToken(allocator, "{c}", .{c});
    try err.withContext(allocator, "symbol");
    return Result(u8).failure(err, stream);
}

// Match any character
pub fn any(stream: Stream, allocator: std.mem.Allocator, _: State) anyerror!Result(u8) {
    if (stream.isEOF()) {
        var err: ParseError = .init(stream.currentLocation);
        try err.expectedPattern(allocator, "character", .{});
        try err.withContext(allocator, "any");
        return Result(u8).failure(err, stream);
    }

    return Result(u8).success(stream.peek(1)[0], stream.eat(1));
}

// Match one of the character given in the array
pub fn oneOf(stream: Stream, allocator: std.mem.Allocator, _: State, x: []const u8) anyerror!Result(u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedPattern(allocator, "noneOf({c})", .{x});
        try err.withContext(allocator, "oneOf");
        return Result(u8).failure(err, stream);
    }

    const peeked = stream.peek(1);
    for (x) |c| {
        if (peeked[0] == c) {
            return Result(u8).success(c, stream.eat(1));
        }
    }

    try err.expectedPattern(allocator, "noneOf({c})", .{x});
    try err.withContext(allocator, "oneOf");
    return Result(u8).failure(err, stream);
}

// Match none of the character given in the array
pub fn noneOf(stream: Stream, allocator: std.mem.Allocator, _: State, x: []const u8) anyerror!Result(u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedToken(allocator, "noneOf({c})", .{x});
        try err.withContext(allocator, "noneOf");
        return Result(u8).failure(err, stream);
    }

    const peeked = stream.peek(1);
    for (x) |c| {
        if (peeked[0] == c) {
            try err.expectedToken(allocator, "noneOf({c})", .{x});
            try err.withContext(allocator, "noneOf");
            return Result(u8).failure(err, stream);
        }
    }

    return Result(u8).success(peeked[0], stream.eat(1));
}

// Match a character between l and h
pub fn range(stream: Stream, allocator: std.mem.Allocator, _: State, l: u8, h: u8) anyerror!Result(u8) {
    std.debug.assert(l < h);
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedToken(allocator, "{c} .. {c}", .{ l, h });
        try err.withContext(allocator, "range");
        return Result(u8).failure(err, stream);
    }

    const peeked = stream.peek(1);
    if (peeked[0] >= l and peeked[0] <= h) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    try err.expectedPattern(allocator, "{c} .. {c}", .{ l, h });
    try err.withContext(allocator, "range");
    return Result(u8).failure(err, stream);
}

// Match a uppercase letter
pub fn upper(stream: Stream, allocator: std.mem.Allocator, _: State) anyerror!Result(u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedPattern(allocator, "uppercase character", .{});
        try err.withContext(allocator, "upper");
        return Result(u8).failure(err, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isUpper(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    try err.expectedPattern(allocator, "uppercase character", .{});
    try err.withContext(allocator, "upper");
    return Result(u8).failure(err, stream);
}

// Match a lowercase letter
pub fn lower(stream: Stream, allocator: std.mem.Allocator, _: State) anyerror!Result(u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedPattern(allocator, "lowercase character", .{});
        try err.withContext(allocator, "lower");
        return Result(u8).failure(err, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isLower(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    try err.expectedPattern(allocator, "lowercase character", .{});
    try err.withContext(allocator, "lower");
    return Result(u8).failure(err, stream);
}

// Match a upper or lowercase letter
pub fn alpha(stream: Stream, allocator: std.mem.Allocator, _: State) anyerror!Result(u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedPattern(allocator, "alpha", .{});
        try err.withContext(allocator, "alpha");
        return Result(u8).failure(err, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isAlphabetic(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    try err.expectedPattern(allocator, "alphabetical character", .{});
    try err.withContext(allocator, "alpha");
    return Result(u8).failure(err, stream);
}

// Match a upper or lowercase letter or a digit
pub fn alphaNum(stream: Stream, allocator: std.mem.Allocator, _: State) anyerror!Result(u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedPattern(allocator, "alpha numerical character", .{});
        try err.withContext(allocator, "alphaNum");
        return Result(u8).failure(err, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isAlphanumeric(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    try err.expectedPattern(allocator, "alpha numerical character", .{});
    try err.withContext(allocator, "alphaNum");
    return Result(u8).failure(err, stream);
}

// Match a digit
pub fn digit(stream: Stream, allocator: std.mem.Allocator, _: State) anyerror!Result(u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedPattern(allocator, "digit", .{});
        try err.withContext(allocator, "digit");
        return Result(u8).failure(err, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isDigit(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    try err.expectedPattern(allocator, "digit", .{});
    try err.withContext(allocator, "digit");
    return Result(u8).failure(err, stream);
}

// Match a octal digit
pub fn octDigit(stream: Stream, allocator: std.mem.Allocator, _: State) anyerror!Result(u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedPattern(allocator, "octal digit", .{});
        try err.withContext(allocator, "octDigit");
        return Result(u8).failure(err, stream);
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

    try err.expectedPattern(allocator, "octal digit", .{});
    try err.withContext(allocator, "octDigit");
    return Result(u8).failure(err, stream);
}

// Match a hexadecimal digit
pub fn hexDigit(stream: Stream, allocator: std.mem.Allocator, _: State) anyerror!Result(u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedPattern(allocator, "hexadecimal digit", .{});
        try err.withContext(allocator, "hexDigit");
        return Result(u8).failure(err, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isHex(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    try err.expectedPattern(allocator, "hexadecimal digit", .{});
    try err.withContext(allocator, "hexDigit");
    return Result(u8).failure(err, stream);
}

// Match a character statisfying the given function
pub fn satisfy(stream: Stream, allocator: std.mem.Allocator, _: State, fnc: *const fn (u8) bool) anyerror!Result(u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedCustom(allocator, "couldn't satisfy {s}", .{@typeName(@TypeOf(fnc))});
        try err.withContext(allocator, "satisfy");
        return Result(u8).failure(err, stream);
    }

    const peeked = stream.peek(1);
    if (fnc(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    try err.expectedCustom(allocator, "couldn't satisfy {s}", .{@typeName(@TypeOf(fnc))});
    try err.withContext(allocator, "satisfy");
    return Result(u8).failure(err, stream);
}

// Match a whitespace
pub fn space(stream: Stream, allocator: std.mem.Allocator, _: State) anyerror!Result(u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedToken(allocator, "' '(space)", .{});
        try err.withContext(allocator, "space");
        return Result(u8).failure(err, stream);
    }

    const peeked = stream.peek(1);
    if (std.ascii.isWhitespace(peeked[0])) {
        return Result(u8).success(peeked[0], stream.eat(1));
    }

    try err.expectedToken(allocator, "' '(space)", .{});
    try err.withContext(allocator, "space");
    return Result(u8).failure(err, stream);
}

// Match multiple whitespaces
pub fn spaces(stream: Stream, _: std.mem.Allocator, _: State) anyerror!Result(void) {
    if (stream.isEOF()) return Result(void).success(void{}, stream);
    const start = stream.currentLocation.index;
    var end = start;

    while (end < stream.data.len and std.ascii.isWhitespace(stream.data[end])) : (end += 1) {}

    return Result(void).success(void{}, stream.eat(end - start));
}

// Match a given string
pub fn string(stream: Stream, allocator: std.mem.Allocator, _: State, str: []const u8) anyerror!Result([]const u8) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedToken(allocator, "\"{s}\"", .{str});
        try err.withContext(allocator, "string");
        return Result([]const u8).failure(err, stream);
    }

    const peeked = stream.peek(str.len);
    if (peeked.len == str.len and std.mem.eql(u8, peeked, str)) {
        return Result([]const u8).success(str, stream.eat(str.len));
    }

    try err.expectedToken(allocator, "\"{s}\"", .{str});
    try err.withContext(allocator, "string");
    return Result([]const u8).failure(err, stream);
}
