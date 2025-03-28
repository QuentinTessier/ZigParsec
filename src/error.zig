const std = @import("std");

pub fn Error(comptime I: type) type {
    return struct {
        I,
        std.builtin.SourceLocation,
    };
}
