const std = @import("std");

pub fn Result(comptime S: type, comptime V: type, comptime E: type) type {
    return union(enum(u32)) {
        result: struct {
            value: V,
            rest: S,
        },
        @"error": struct {
            value: E,
            rest: S,
        },

        pub fn success(value: V, rest: S) @This() {
            return .{ .result = .{ .value = value, .rest = rest } };
        }

        pub fn failure(value: E, rest: S) @This() {
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
