const std = @import("std");
const Stream = @import("Stream.zig");
pub const ParseError = @import("error/ParseError.zig");

pub fn EitherResultOrError(comptime Value: type, comptime Err: type) type {
    return union(enum(u32)) {
        Result: struct {
            value: Value,
            rest: Stream,
        },
        Error: struct {
            msg: Err,
            rest: Stream,
        },

        pub fn success(value: Value, rest: Stream) @This() {
            return .{ .Result = .{ .value = value, .rest = rest } };
        }

        pub fn failure(value: Err, rest: Stream) @This() {
            return .{ .Error = .{ .msg = value, .rest = rest } };
        }

        pub fn convertError(otherError: anytype) @This() {
            switch (otherError) {
                .Result => unreachable,
                .Error => |e| return .{ .Error = .{ .msg = e.msg, .rest = e.rest } },
            }
        }
    };
}

pub fn Result(comptime Value: type) type {
    return EitherResultOrError(Value, ParseError);
}
