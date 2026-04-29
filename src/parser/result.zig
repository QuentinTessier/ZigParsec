const std = @import("std");
const Error = @import("error.zig").Error;

pub fn Result(comptime S: type, comptime V: type, comptime E: type) type {
    return union(enum(u32)) {
        pub const StreamType = S;
        pub const ValueType = V;
        pub const ErrorType = E;

        result: struct {
            value: V,
            rest: S,
        },
        @"error": struct {
            value: Error(E),
            rest: S,
        },

        pub fn success(value: V, rest: S) @This() {
            return .{ .result = .{ .value = value, .rest = rest } };
        }

        pub fn failure(value: Error(E), rest: S) @This() {
            return .{ .@"error" = .{ .value = value, .rest = rest } };
        }

        pub fn stream(self: *const @This()) S {
            return switch (self.*) {
                .result => |val| val.rest,
                .@"error" => |val| val.rest,
            };
        }
    };
}
