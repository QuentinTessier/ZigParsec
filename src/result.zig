const std = @import("std");

pub fn Result(comptime I: type, comptime T: type, comptime E: type) type {
    return union(enum) {
        pub const ValueType = T;

        res: struct { I, T },
        err: E,

        pub fn unwrap(self: @This(), err: *E) ?struct { I, T } {
            return switch (self) {
                .res => |r| r,
                .err => |e| blk: {
                    err.* = e;
                    break :blk null;
                },
            };
        }
    };
}
