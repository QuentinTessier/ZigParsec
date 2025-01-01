const std = @import("std");
pub const ExampleMath = @import("examples/math.zig");
pub const BaseState = @import("UserState.zig").BaseState;
pub const MakeUserStateType = @import("UserState.zig").MakeUserStateType;
pub const Result = @import("Result.zig").Result;
pub const ParseError = @import("Result.zig").ParseError;

// TODO: Tests
// TODO: Better ParserError type
// TODO: Rework examples
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

pub fn eof(stream: Stream, allocator: std.mem.Allocator, _: *BaseState) anyerror!Result(void) {
    if (stream.isEOF()) return Result(void).success(void{}, stream);
    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Expected EndOfStream", .{stream});
    return Result(void).failure(error_msg, stream);
}

// T: return type of the given parser
// p: Resolved at comptime:
// --- Either a parser has a function with no extra arguments
// --- Or a tuple of a parser function and a tuple of it's arguments (e.g: .{ fn, .{ ... } })
// --- Or a structure with 2 fields, a parser function and a tuple of it's arguments (e.g: .{ .parser = fn, .args = .{ ... } })
pub inline fn runParser(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime T: type, p: anytype) anyerror!Result(T) {
    const ParserWrapperType: type = @TypeOf(p);
    return switch (@typeInfo(ParserWrapperType)) {
        .Struct => |s| if (s.is_tuple) @call(.auto, p[0], .{ stream, allocator, state } ++ p[1]) else @call(.auto, p.parser, .{ stream, allocator, state } ++ p.args),
        .Fn => @call(.auto, p, .{ stream, allocator, state }),
        else => blk: {
            if (std.debug.runtime_safety) @panic("Invalid Parser given with type: " ++ @typeName(ParserWrapperType));
            var msg = std.ArrayList(u8).init(allocator);
            var writer = msg.writer();
            try writer.print("Invalid Parser given with type: {s}", .{@typeName(ParserWrapperType)});
            break :blk Result(T).failure(msg, stream);
        },
    };
}

// Run parsers p, if it fails, replace the error message with the given string
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

// Return parser, never fails, always return x
// Usefull has a fallback
pub inline fn ret(stream: Stream, _: std.mem.Allocator, _: *BaseState, comptime Value: type, x: Value) anyerror!Result(Value) {
    return Result(Value).success(x, stream);
}

// return parser fParser and run tFunc on the result if successful
pub inline fn map(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime From: type, fParser: anytype, comptime To: type, tFnc: *const fn (std.mem.Allocator, From) anyerror!To) anyerror!Result(To) {
    return switch (try runParser(stream, allocator, state, From, fParser)) {
        .Result => |res| Result(To).success(try tFnc(allocator, res.value), res.rest),
        .Error => |err| Result(To).failure(err.msg, err.rest),
    };
}

// S: a structure
// mapped_parsers: a list of parsers with it's associated field
// --- Parsers are applied in the order they are given.
// Example:
//
// const TestStruct = struct {
//     a: u8,
//     b: []const u8,
//     c: u8,
// };
//
// toStruct(stream, allocator, state, TestStruct, &.{
//     .{ .a, u8, .{ Char.symbol, .{'a'} } }, // first parser, try to match 'a' and populate TestStruct.a with it.
//     .{ void, u8, .{ Char.symbol, .{','} } }, // Tries to match ',' but doesn't populate any field.
//     .{ .b, []const u8, .{ Char.string, .{"amazing"} } }, // Tries to match "amazing" and populate TestStruct.b with it.
//     .{ .c, u8, .{ Char.symbol, .{'c'} } }, // Tried to match 'c' and populate TestStruct.c with it.
// });
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

// U: union type
// mapped_parsers: a list of parsers with it's associated field
// --- Parsers are applied in the order they are given.
// Example:
// const TaggedUnionTest = union(enum(u32)) {
//     a: u8,
//     b: []const u8,
// };
//
// toTaggedUnion(stream, allocator, state, TaggedUnionTest, &.{
//     .{ .a, u8, .{ Char.symbol, .{'a'} } }, // If this parser succeed, return TaggedUnionTest{ .a = 'a' }
//     .{ .b, []const u8, .{ Char.string, .{"amazing"} } }, // If this parser succeed, return TaggedUnionTest{ .b = "amazing" }
// });
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
