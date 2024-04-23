const std = @import("std");
const Stream = @import("Stream.zig");

pub fn Combinator(comptime UserState: type) type {
    return struct {
        const Result = @import("Parser.zig").Parser(UserState).Result;
        const runParser = @import("Parser.zig").Parser(UserState).runParser;

        pub fn many(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime Value: type, p: anytype) anyerror!Result([]Value) {
            var array = std.ArrayList(Value).init(allocator);
            var s = stream;
            while (true) {
                const r = try runParser(s, allocator, state, Value, p);
                switch (r) {
                    .Result => |res| {
                        s = res.rest;
                        try array.append(res.value);
                    },
                    .Error => break,
                }
            }
            return Result([]Value).success(try array.toOwnedSlice(), s);
        }

        pub fn many1(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime Value: type, p: anytype) anyerror!Result([]Value) {
            var array = std.ArrayList(Value).init(allocator);
            var s = stream;
            var r: Result(Value) = undefined;
            var count: usize = 0;
            while (true) {
                r = try runParser(s, allocator, state, Value, p);
                switch (r) {
                    .Result => |res| {
                        count += 1;
                        s = res.rest;
                        try array.append(res.value);
                    },
                    .Error => |err| {
                        if (count != 0) {
                            err.msg.deinit();
                        }
                        break;
                    },
                }
            }
            if (count == 0) {
                array.deinit();
                var error_msg = std.ArrayList(u8).init(allocator);
                var writer = error_msg.writer();
                try writer.print("{}: Expected at least one element, found:\n\t{s}", .{ stream, r.Error.msg.items });
                r.Error.msg.deinit();
                return Result([]Value).failure(error_msg, stream);
            }
            return Result([]Value).success(try array.toOwnedSlice(), s);
        }

        pub fn choice(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime Value: type, parsers: anytype) anyerror!Result(Value) {
            var error_msg = std.ArrayList(u8).init(allocator);
            var writer = error_msg.writer();
            try writer.print("{}: Choice Parser:\n", .{stream});
            for (parsers) |p| {
                const r = try runParser(stream, allocator, state, Value, p);
                switch (r) {
                    .Result => {
                        error_msg.deinit();
                        return r;
                    },
                    .Error => |err| {
                        try writer.print("\t{s}\n", .{err});
                        err.msg.deinit();
                    },
                }
            }
            return Result(Value).failure(error_msg, stream);
        }

        pub fn between(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime Values: [3]type, start: anytype, parser: anytype, end: anytype) anyerror!Result(Values[1]) {
            switch (try runParser(stream, allocator, state, Values[0], start)) {
                .Result => |res_start| {
                    switch (try runParser(res_start.rest, allocator, state, Values[1], parser)) {
                        .Result => |res_parser| {
                            switch (try runParser(res_parser.rest, allocator, state, Values[2], end)) {
                                .Result => |res_end| return Result(Values[1]).success(res_parser.value, res_end.rest),
                                .Error => |err| return Result(Values[1]).failure(err.msg, err.rest),
                            }
                        },
                        .Error => |err| return Result(Values[1]).failure(err.msg, err.rest),
                    }
                },
                .Error => |err| return Result(Values[1]).failure(err.msg, err.rest),
            }
        }

        pub fn option(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime Value: type, x: Value, parser: anytype) anyerror!Result(Value) {
            const r = try runParser(stream, allocator, state, Value, parser);
            return switch (r) {
                .Result => r,
                .Error => |err| blk: {
                    if (stream.diff(err.rest).len == 0)
                        break :blk Result(Value).success(x, err.rest)
                    else
                        break :blk r;
                },
            };
        }

        pub fn optionMaybe(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime Value: type, parser: anytype) anyerror!Result(?Value) {
            const r = try runParser(stream, allocator, state, Value, parser);
            return switch (r) {
                .Result => r,
                .Error => |err| blk: {
                    if (stream.diff(err.rest).len == 0)
                        break :blk Result(Value).success(null, err.rest)
                    else
                        break :blk r;
                },
            };
        }

        pub fn optional(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime Value: type, parser: anytype) anyerror!Result(void) {
            const r = try runParser(stream, allocator, state, Value, parser);
            return switch (r) {
                .Result => |res| Result(void).success(void{}, res.rest),
                .Error => |err| blk: {
                    if (stream.diff(err.rest).len == 0)
                        break :blk Result(Value).success(void{}, err.rest)
                    else
                        break :blk r;
                },
            };
        }

        pub fn sepBy(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime PValue: type, parser: anytype, comptime SValue: type, sep: anytype) anyerror!Result([]PValue) {
            var array = std.ArrayList(PValue).init(allocator);
            var s = stream;

            switch (try runParser(s, allocator, state, PValue, parser)) {
                .Result => |res| {
                    try array.append(res.value);
                    s = res.rest;
                },
                .Error => |err| {
                    err.msg.deinit();
                    return Result([]PValue).success(&.{}, err.rest);
                },
            }

            while (run: {
                switch (try runParser(s, allocator, state, SValue, sep)) {
                    .Result => |res| {
                        s = res.rest;
                        break :run true;
                    },
                    .Error => |err| {
                        err.msg.deinit();
                        break :run false;
                    },
                }
            }) {
                switch (try runParser(s, allocator, state, PValue, parser)) {
                    .Result => |res| {
                        try array.append(res.value);
                        s = res.rest;
                    },
                    .Error => |err| {
                        array.deinit();
                        return Result([]PValue).failure(err.msg, err.rest);
                    },
                }
            }

            return Result([]PValue).success(try array.toOwnedSlice(), s);
        }

        pub fn sepBy1(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime PValue: type, parser: anytype, comptime SValue: type, sep: anytype) anyerror!Result([]PValue) {
            var array = std.ArrayList(PValue).init(allocator);
            var s = stream;

            switch (try runParser(s, allocator, state, PValue, parser)) {
                .Result => |res| {
                    try array.append(res.value);
                    s = res.rest;
                },
                .Error => |err| return Result([]PValue).failure(err.msg, err.rest),
            }

            while (run: {
                switch (try runParser(s, allocator, state, SValue, sep)) {
                    .Result => |res| {
                        s = res.rest;
                        break :run true;
                    },
                    .Error => |err| {
                        err.msg.deinit();
                        break :run false;
                    },
                }
            }) {
                switch (try runParser(s, allocator, state, PValue, parser)) {
                    .Result => |res| {
                        try array.append(res.value);
                        s = res.rest;
                    },
                    .Error => |err| {
                        array.deinit();
                        return Result([]PValue).failure(err.msg, err.rest);
                    },
                }
            }

            return Result([]PValue).success(try array.toOwnedSlice(), s);
        }
    };
}
