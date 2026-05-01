const std = @import("std");

const Result = @import("result.zig").Result;
const Error = @import("error.zig").Error;

pub fn Parser(comptime S: type, comptime V: type, comptime E: type) type {
    return *const fn (S, std.mem.Allocator) anyerror!Result(S, V, E);
}

fn UnwrapError(comptime R: type) type {
    switch (@typeInfo(R)) {
        .error_union => |e| return e.payload,
        else => @compileError("Expected a error union"),
    }
}

pub fn ParserResult(comptime P: type) type {
    switch (@typeInfo(P)) {
        .@"fn" => |f| return UnwrapError(f.return_type.?),
        .pointer => |p| return ParserResult(p.child),
        else => @compileError("Expected a function or a function pointer"),
    }
}

pub fn Fatal(comptime S: type, comptime P: anytype, comptime E: type) blk: {
    const PResult = ParserResult(@TypeOf(P));
    const ValueType = PResult.ValueType;
    break :blk Parser(S, ValueType, E);
} {
    const PResult = ParserResult(@TypeOf(P));
    const ValueType = PResult.ValueType;
    const R = Result(S, ValueType, E);

    return struct {
        pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
            const res: R = try P(stream, allocator);
            return switch (res) {
                .result => res,
                .@"error" => |err| R.failure(err.value.promote(), err.rest),
            };
        }
    }.inline_parser;
}
