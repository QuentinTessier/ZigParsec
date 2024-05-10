const std = @import("std");
pub const ExampleMath = @import("examples/math.zig");
pub const BaseState = @import("UserState.zig").BaseState;
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

pub fn pure(stream: Stream, _: std.mem.Allocator, _: *BaseState) anyerror!Result(void) {
    return Result(void).success(void{}, stream);
}

pub fn noop(stream: Stream, allocator: std.mem.Allocator, _: *BaseState) anyerror!Result(void) {
    var error_msg: ParseError = ParseError.init(allocator);
    try error_msg.appendSlice("Encountered parser NOOP");
    return Result(void).failure(error_msg, stream);
}

pub inline fn runParser(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime T: type, p: anytype) anyerror!Result(T) {
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

pub inline fn label(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Value: type, p: anytype, str: []const u8) anyerror!Result(Value) {
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

pub inline fn ret(stream: Stream, _: std.mem.Allocator, _: *BaseState, comptime Value: type, x: Value) anyerror!Result(Value) {
    return Result(Value).success(x, stream);
}

pub inline fn map(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime From: type, fParser: anytype, comptime To: type, tFnc: *const fn (std.mem.Allocator, From) anyerror!To) anyerror!Result(To) {
    return switch (try runParser(stream, allocator, state, From, fParser)) {
        .Result => |res| Result(To).success(try tFnc(allocator, res.value), res.rest),
        .Error => |err| Result(To).failure(err.msg, err.rest),
    };
}

pub fn toStruct(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime S: type, comptime mapped_parsers: anytype) anyerror!Result(S) {
    if (@typeInfo(S) != .Struct or @typeInfo(S).Struct.is_tuple == true) {
        @compileError("toStruct expectes a struct type has arguments, got another type or a tuple");
    }

    var s: S = undefined;
    var str = stream;
    inline for (mapped_parsers) |field_parser_tuple| {
        const maybe_field = field_parser_tuple[0];
        const t = field_parser_tuple[1];
        const parser = field_parser_tuple[2];

        if (@TypeOf(maybe_field) == type and maybe_field == void) {
            switch (try runParser(str, allocator, state, t, parser)) {
                .Result => |res| {
                    str = res.rest;
                },
                .Error => |err| return Result(S).failure(err.msg, err.rest),
            }
        } else {
            const field = maybe_field;
            switch (try runParser(str, allocator, state, t, parser)) {
                .Result => |res| {
                    @field(s, std.meta.fieldInfo(S, field).name) = res.value;
                    str = res.rest;
                },
                .Error => |err| return Result(S).failure(err.msg, err.rest),
            }
        }
    }
    return Result(S).success(s, str);
}

pub fn toTaggedUnion(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime U: type, comptime mapped_parsers: anytype) anyerror!Result(U) {
    if (@typeInfo(U) != .Union) {
        @panic("");
    }

    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Choice Parser:\n", .{stream});
    inline for (mapped_parsers) |field_parser_tuple| {
        const field = field_parser_tuple[0];
        const t = field_parser_tuple[1];
        const parser = field_parser_tuple[2];

        switch (try runParser(stream, allocator, state, t, parser)) {
            .Result => |res| {
                error_msg.deinit();
                return Result(U).success(@unionInit(U, std.meta.fieldInfo(U, field).name, res.value), res.rest);
            },
            .Error => |err| {
                try writer.print("\t{s}\n", .{err.msg.items});
                err.msg.deinit();
            },
        }
    }
    return Result(U).failure(error_msg, stream);
}
