const std = @import("std");
const Stream = @import("Stream.zig");
const Result = @import("Result.zig").Result;
const BaseState = @import("UserState.zig").BaseState;

const runParser = @import("Parser.zig").runParser;

// Apply parser p zero or more time
pub fn many(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Value: type, p: anytype) anyerror!Result([]Value) {
    var array = std.ArrayList(Value).init(allocator);
    var s = stream;
    while (true) {
        const r = try runParser(s, allocator, state, Value, p);
        switch (r) {
            .Result => |res| {
                s = res.rest;
                try array.append(res.value);
            },
            .Error => |err| {
                err.msg.deinit();
                break;
            },
        }
    }
    return Result([]Value).success(try array.toOwnedSlice(), s);
}

// Apply parser p one or more time
pub fn many1(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Value: type, p: anytype) anyerror!Result([]Value) {
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

// Apply parser p zero or more time ignoring the return value
pub fn skipMany(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Value: type, p: anytype) anyerror!Result(void) {
    var s = stream;
    while (true) {
        const r = try runParser(s, allocator, state, Value, p);
        switch (r) {
            .Result => |res| {
                s = res.rest;
            },
            .Error => |err| {
                err.msg.deinit();
                break;
            },
        }
    }
    return Result([]Value).success(void{}, s);
}

// Run the given parsers sequentialy and return the first successful parser
pub fn choice(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Value: type, parsers: anytype) anyerror!Result(Value) {
    var error_msg = std.ArrayList(u8).init(allocator);
    var writer = error_msg.writer();
    try writer.print("{}: Choice Parser:\n", .{stream});
    inline for (parsers) |p| {
        const r = try runParser(stream, allocator, state, Value, p);
        switch (r) {
            .Result => {
                error_msg.deinit();
                return r;
            },
            .Error => |err| {
                try writer.print("\t{s}\n", .{err.msg.items});
                err.msg.deinit();
            },
        }
    }
    return Result(Value).failure(error_msg, stream);
}

pub fn between(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Values: [3]type, start: anytype, parser: anytype, end: anytype) anyerror!Result(Values[1]) {
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

pub fn option(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Value: type, x: Value, parser: anytype) anyerror!Result(Value) {
    const r = try runParser(stream, allocator, state, Value, parser);
    return switch (r) {
        .Result => r,
        .Error => |err| blk: {
            if (stream.diff(err.rest).len == 0) {
                err.msg.deinit();
                break :blk Result(Value).success(x, err.rest);
            } else break :blk r;
        },
    };
}

pub fn optionMaybe(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Value: type, parser: anytype) anyerror!Result(?Value) {
    const r = try runParser(stream, allocator, state, Value, parser);
    return switch (r) {
        .Result => |res| Result(?Value).success(res.value, res.rest),
        .Error => |err| blk: {
            if (stream.diff(err.rest).len == 0) {
                err.msg.deinit();
                break :blk Result(?Value).success(null, err.rest);
            } else break :blk Result(?Value).convertError(r);
        },
    };
}

pub fn optional(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime Value: type, parser: anytype) anyerror!Result(void) {
    const r = try runParser(stream, allocator, state, Value, parser);
    return switch (r) {
        .Result => |res| Result(void).success(void{}, res.rest),
        .Error => |err| blk: {
            if (stream.diff(err.rest).len == 0) {
                err.msg.deinit();
                break :blk Result(void).success(void{}, err.rest);
            } else break :blk Result(void).convertError(r);
        },
    };
}

pub fn sepBy(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime PValue: type, parser: anytype, comptime SValue: type, sep: anytype) anyerror!Result([]PValue) {
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

pub fn sepBy1(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime PValue: type, parser: anytype, comptime SValue: type, sep: anytype) anyerror!Result([]PValue) {
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

pub fn notFollowedBy(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime PValue: type, parser: anytype, comptime FValue: type, follow: anytype) anyerror!Result(PValue) {
    switch (try runParser(stream, allocator, state, PValue, parser)) {
        .Result => |res| {
            switch (try runParser(res.rest, allocator, state, FValue, follow)) {
                .Result => return Result(PValue).failure(std.ArrayList(u8).init(allocator), res.rest),
                .Error => |err| {
                    err.msg.deinit();
                    return Result(PValue).success(res.value, res.rest);
                },
            }
        },
        .Error => |err| return Result(PValue).failure(err.msg, err.rest),
    }
}

fn lscan(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime PValue: type, parser: anytype, comptime OValue: type, op: anytype) anyerror!Result(PValue) {
    return switch (try runParser(stream, allocator, state, PValue, parser)) {
        .Result => |res| lrest(res.rest, allocator, state, PValue, parser, OValue, op, res.value),
        .Error => |err| Result(PValue).failure(err.msg, err.rest),
    };
}

fn lrest(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime PValue: type, parser: anytype, comptime OValue: type, op: anytype, x: PValue) anyerror!Result(PValue) {
    switch (try runParser(stream, allocator, state, OValue, op)) {
        .Result => |res| {
            const operator_fnc: *const fn (std.mem.Allocator, PValue, PValue) anyerror!PValue = res.value;
            switch (try lscan(res.rest, allocator, state, PValue, parser, OValue, op)) {
                .Result => |res2| return Result(PValue).success(try operator_fnc(allocator, x, res2.value), res2.rest),
                .Error => |err| {
                    err.msg.deinit();
                },
            }
        },
        .Error => |err| {
            err.msg.deinit();
        },
    }
    return Result(PValue).success(x, stream);
}

pub fn chainl1(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime PValue: type, parser: anytype, comptime OValue: type, op: anytype) anyerror!Result(PValue) {
    return switch (try lscan(stream, allocator, state, PValue, parser, OValue, op)) {
        .Result => |res| lrest(res.rest, allocator, state, PValue, parser, OValue, op, res.value),
        .Error => |err| Result(PValue).failure(err.msg, err.rest),
    };
}

pub fn chainl(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime PValue: type, parser: anytype, comptime OValue: type, op: anytype, x: PValue) anyerror!Result(PValue) {
    switch (try chainl1(stream, allocator, state, PValue, parser, OValue, op)) {
        .Result => |res| return Result(PValue).success(res.value, res.rest),
        .Error => |err| {
            err.msg.deinit();
            return Result(PValue).success(x, err.rest);
        },
    }
}

pub fn untilNoAlloc(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, parser: anytype, comptime EValue: type, end: anytype) anyerror!Result([]const u8) {
    var s = stream;
    while (blk: {
        switch (try runParser(s, allocator, state, EValue, end)) {
            .Result => |res| {
                s = res.rest;
                break :blk false;
            },
            .Error => |err| {
                err.msg.deinit();
                s = err.rest;
                break :blk true;
            },
        }
    }) {
        switch (try runParser(s, allocator, state, u8, parser)) {
            .Result => |res| {
                s = res.rest;
            },
            .Error => |err| {
                return Result([]const u8).failure(err.msg, err.rest);
            },
        }
    }
    return Result([]const u8).success(stream.diff(s), s);
}

pub fn until(stream: Stream, allocator: std.mem.Allocator, state: *BaseState, comptime PValue: type, parser: anytype, comptime EValue: type, end: anytype) anyerror!Result([]PValue) {
    var array = std.ArrayList(PValue).init(allocator);

    var s = stream;
    while (blk: {
        switch (try runParser(s, allocator, state, EValue, end)) {
            .Result => |res| {
                s = res.rest;
                break :blk false;
            },
            .Error => |err| {
                err.msg.deinit();
                s = err.rest;
                break :blk true;
            },
        }
    }) {
        switch (try runParser(s, allocator, state, PValue, parser)) {
            .Result => |res| {
                s = res.rest;
                try array.append(res.value);
            },
            .Error => |err| {
                array.deinit();
                return Result([]PValue).failure(err.msg, err.rest);
            },
        }
    }
    return Result([]PValue).success(try array.toOwnedSlice(), s);
}
