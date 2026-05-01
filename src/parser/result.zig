const std = @import("std");
const Error = @import("error.zig").Error;

pub fn ErrorPayload(comptime S: type, comptime E: type) type {
    return struct {
        value: Error(E),
        rest: S,
    };
}

pub fn Result(comptime S: type, comptime V: type, comptime E: type) type {
    return union(enum(u32)) {
        pub const StreamType = S;
        pub const ValueType = V;
        pub const ErrorType = E;

        pub const ResultPayload = struct {
            value: V,
            rest: S,
        };

        result: ResultPayload,
        @"error": ErrorPayload(S, E),

        pub fn success(value: V, rest: S) @This() {
            return .{ .result = .{ .value = value, .rest = rest } };
        }

        // TODO: Provide better constructor, failure(ErrorPayload), failure(ErrorPayload.promote()), ...
        pub fn failure(value: Error(E), rest: S) @This() {
            return .{ .@"error" = .{ .value = value, .rest = rest } };
        }

        pub fn stream(self: *const @This()) S {
            return switch (self.*) {
                .result => |val| val.rest,
                .@"error" => |val| val.rest,
            };
        }

        pub fn map(self: *const @This(), comptime U: type, allocator: std.mem.Allocator, f: *const fn (allocator: std.mem.Allocator, value: V) anyerror!U) anyerror!Result(S, U, E) {
            return switch (self.*) {
                .@"error" => |err| .failure(err.value, err.rest),
                .result => |res| .success(try f(allocator, res.value), res.rest),
            };
        }

        pub fn unwrap(self: *const @This(), err: ?*ErrorPayload(S, E)) ?ResultPayload {
            return switch (self.*) {
                .@"error" => |e| blk: {
                    if (err) |ptr| ptr.* = e;
                    break :blk null;
                },
                .result => |r| r,
            };
        }
    };
}
