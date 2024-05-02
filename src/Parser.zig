const std = @import("std");
pub const ExampleMath = @import("examples/math.zig");
pub const ZigParsecState = @import("UserState.zig").ZigParsecState;
pub const MakeUserStateType = @import("UserState.zig").MakeUserStateType;
pub const Result = @import("Result.zig").Result;
pub const ParseError = @import("Result.zig").ParseError;

// TODO: Basic Language parser (integer, float, keyword, identifier, ...)
// TODO: Tests
// TODO: Change the way we can eat whitespace.
// ----- Stream.eatWhitespace isn't the way, works for simple parser, but becomes anoying when trying to do more complicated things
// ----- See Combinator.skipMany => create Char.skipeManySpaces ...
pub const Stream = @import("Stream.zig");
pub const Char = @import("Char.zig");
pub const Combinator = @import("Combinator.zig");
pub const Language = @import("Language.zig");
pub const Expression = @import("Expression.zig").BuildExpressionParser;

pub fn pure(stream: Stream, _: std.mem.Allocator, _: *ZigParsecState) anyerror!Result(void) {
    return Result(void).success(void{}, stream);
}

pub fn noop(stream: Stream, allocator: std.mem.Allocator, _: *ZigParsecState) anyerror!Result(void) {
    var error_msg: ParseError = ParseError.init(allocator);
    try error_msg.appendSlice("Encountered parser NOOP");
    return Result(void).failure(error_msg, stream);
}

pub inline fn runParser(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, comptime T: type, p: anytype) anyerror!Result(T) {
    const ParserWrapperType: type = @TypeOf(p);
    return switch (@typeInfo(ParserWrapperType)) {
        .Struct => |s| if (s.is_tuple) @call(.auto, p[0], .{ stream, allocator, state } ++ p[1]) else @call(.auto, p.parser, .{ stream, allocator, state } ++ p.args),
        .Fn => @call(.auto, p, .{ stream, allocator, state }),
        else => blk: {
            var msg = std.ArrayList(u8).init(allocator);
            var writer = msg.writer();
            try writer.print("Invalid Parser given with type: {s}", .{@typeName(p)});
            break :blk Result(T).failure(msg, stream);
        },
    };
}

pub inline fn label(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, comptime Value: type, p: anytype, str: []const u8) anyerror!Result(Value) {
    const r = try runParser(stream, allocator, state, Value, p);
    switch (r) {
        .Result => return r,
        .Error => |err| {
            var error_msg = std.ArrayList(u8).init(allocator);
            var writer = error_msg.writer();
            try writer.print("{}: {s}", .{ stream, str });
            err.msg.deinit();
            return Result([]Value).failure(error_msg, stream);
        },
    }
}

pub inline fn ret(stream: Stream, _: std.mem.Allocator, _: *ZigParsecState, comptime Value: type, x: Value) anyerror!Result(Value) {
    return Result(Value).success(x, stream);
}

pub inline fn map(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, comptime From: type, fParser: anytype, comptime To: type, tFnc: *const fn (std.mem.Allocator, From) anyerror!To) anyerror!Result(To) {
    return switch (try runParser(stream, allocator, state, From, fParser)) {
        .Result => |res| Result(To).success(try tFnc(allocator, res.value), res.rest),
        .Error => |err| Result(To).failure(err.msg, err.rest),
    };
}
