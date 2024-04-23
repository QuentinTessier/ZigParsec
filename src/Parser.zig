const std = @import("std");
pub const ExampleMath = @import("examples/math.zig");

// TODO: Make UserState compatible with void
pub fn Parser(comptime UserState: type) type {
    return struct {
        pub const Stream = @import("Stream.zig");
        pub const Char = @import("Char.zig").Char(UserState);
        pub const Combinator = @import("Combinator.zig").Combinator(UserState);

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

        pub const ParseError = std.ArrayList(u8);

        pub fn Result(comptime Value: type) type {
            return EitherResultOrError(Value, ParseError);
        }

        pub fn pure(stream: Stream, _: std.mem.Allocator, _: *UserState) anyerror!Result(void) {
            return Result(void).success(void{}, stream);
        }

        pub fn noop(stream: Stream, allocator: std.mem.Allocator, _: *UserState) anyerror!Result(void) {
            var error_msg: ParseError = ParseError.init(allocator);
            try error_msg.appendSlice("Encountered parser NOOP");
            return Result(void).failure(error_msg, stream);
        }

        pub inline fn runParser(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime T: type, p: anytype) anyerror!Result(T) {
            const ParserWrapperType: type = @TypeOf(p);
            return switch (@typeInfo(ParserWrapperType)) {
                .Struct => @call(.auto, p.parser, .{ stream, allocator, state } ++ p.args),
                .Fn => @call(.auto, p, .{ stream, allocator, state }),
                else => unreachable,
            };
        }

        pub inline fn label(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime Value: type, p: anytype, str: []const u8) anyerror!Result(Value) {
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
    };
}
