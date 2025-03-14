const std = @import("std");

pub fn ReturnType(comptime Fn: type) type {
    return switch (@typeInfo(Fn)) {
        .@"fn" => |f| f.return_type.?,
        .pointer => |p| ReturnType(p.child),
        else => @compileError("Expected a function got " ++ @typeName(Fn)),
    };
}
