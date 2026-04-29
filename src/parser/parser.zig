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
