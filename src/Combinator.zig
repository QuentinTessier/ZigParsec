const std = @import("std");
const Stream = @import("Stream.zig");
const ParseError = @import("error/ParseError.zig");
const Result = @import("Result.zig").Result;
const State = @import("UserState.zig").State;

const symbol = @import("Char.zig").symbol;

const runParser = @import("Parser.zig").runParser;

// Apply parser p zero or more time
pub fn many(stream: Stream, allocator: std.mem.Allocator, state: State, comptime Value: type, p: anytype) anyerror!Result([]Value) {
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
                err.msg.deinit(allocator);
                break;
            },
        }
    }
    return Result([]Value).success(try array.toOwnedSlice(), s);
}

test "many no input" {
    const stream: Stream = .init("", "test");
    const state: State = .{};

    const res = try many(stream, std.testing.allocator, state, u8, .{ symbol, .{'a'} });
    try std.testing.expect(res == .Result);
    try std.testing.expectEqual(res.Result.value.len, 0);
    try std.testing.expect(res.Result.rest.isEOF());
}

// Apply parser p one or more time
pub fn many1(stream: Stream, allocator: std.mem.Allocator, state: State, comptime Value: type, p: anytype) anyerror!Result([]Value) {
    var array = std.ArrayList(Value).init(allocator);
    var s = stream;
    var r: Result(Value) = try runParser(s, allocator, state, Value, p);
    switch (r) {
        .Result => |res| {
            s = res.rest;
            try array.append(res.value);
        },
        .Error => |err| {
            var local_err: ParseError = .init(stream.currentLocation);
            try local_err.addChild(allocator, &err);
            try local_err.message(allocator, "expected at list on {s} found 0", .{@typeName(Value)});
            return Result([]Value).failure(local_err, stream);
        },
    }

    while (true) {
        r = try runParser(s, allocator, state, Value, p);
        switch (r) {
            .Result => |res| {
                s = res.rest;
                try array.append(res.value);
            },
            .Error => |_| {
                r.Error.msg.deinit(allocator);
                break;
            },
        }
    }
    return Result([]Value).success(try array.toOwnedSlice(), s);
}

// Apply parser p zero or more time ignoring the return value
pub fn skipMany(stream: Stream, allocator: std.mem.Allocator, state: State, comptime Value: type, p: anytype) anyerror!Result(void) {
    var s = stream;
    while (true) {
        const r = try runParser(s, allocator, state, Value, p);
        switch (r) {
            .Result => |res| {
                s = res.rest;
            },
            .Error => |err| {
                err.msg.deinit(allocator);
                break;
            },
        }
    }
    return Result([]Value).success(void{}, s);
}

// Run the given parsers sequentialy and return the first successful parser
pub fn choice(stream: Stream, allocator: std.mem.Allocator, state: State, comptime Value: type, parsers: anytype) anyerror!Result(Value) {
    var error_array: std.ArrayList(ParseError) = try .initCapacity(allocator, parsers.len);
    defer error_array.deinit();

    inline for (parsers) |p| {
        const r = try runParser(stream, allocator, state, Value, p);
        switch (r) {
            .Result => {
                for (error_array.items) |*msg| {
                    msg.deinit(allocator);
                }
                return r;
            },
            .Error => |err| {
                error_array.appendAssumeCapacity(err.msg);
            },
        }
    }
    var merged_error = try ParseError.merge(allocator, error_array.items);
    try merged_error.withContext(allocator, "choice");
    return Result(Value).failure(merged_error, stream);
}

pub fn between(stream: Stream, allocator: std.mem.Allocator, state: State, comptime Values: [3]type, start: anytype, parser: anytype, end: anytype) anyerror!Result(Values[1]) {
    switch (try runParser(stream, allocator, state, Values[0], start)) {
        .Result => |res_start| {
            switch (try runParser(res_start.rest, allocator, state, Values[1], parser)) {
                .Result => |res_parser| {
                    switch (try runParser(res_parser.rest, allocator, state, Values[2], end)) {
                        .Result => |res_end| return Result(Values[1]).success(res_parser.value, res_end.rest),
                        .Error => |err| {
                            var local_error: ParseError = .init(err.rest.currentLocation);
                            try local_error.addChild(allocator, &err.msg);
                            try local_error.withContext(allocator, "between");
                            return Result(Values[1]).failure(local_error, stream);
                        },
                    }
                },
                .Error => |err| {
                    var local_error: ParseError = .init(err.rest.currentLocation);
                    try local_error.addChild(allocator, &err.msg);
                    try local_error.withContext(allocator, "between");
                    return Result(Values[1]).failure(local_error, stream);
                },
            }
        },
        .Error => |err| {
            var local_error: ParseError = .init(err.rest.currentLocation);
            try local_error.addChild(allocator, &err.msg);
            try local_error.withContext(allocator, "between");
            return Result(Values[1]).failure(local_error, stream);
        },
    }
}

pub fn option(stream: Stream, allocator: std.mem.Allocator, state: State, comptime Value: type, x: Value, parser: anytype) anyerror!Result(Value) {
    const r = try runParser(stream, allocator, state, Value, parser);
    return switch (r) {
        .Result => r,
        .Error => |err| blk: {
            if (stream.diff(err.rest).len == 0) {
                err.msg.deinit(allocator);
                break :blk Result(Value).success(x, err.rest);
            } else break :blk r;
        },
    };
}

pub fn optionMaybe(stream: Stream, allocator: std.mem.Allocator, state: State, comptime Value: type, parser: anytype) anyerror!Result(?Value) {
    const r = try runParser(stream, allocator, state, Value, parser);
    return switch (r) {
        .Result => |res| Result(?Value).success(res.value, res.rest),
        .Error => |err| blk: {
            if (stream.diff(err.rest).len == 0) {
                r.Error.msg.deinit(allocator);
                break :blk Result(?Value).success(null, err.rest);
            } else {
                var local_err: ParseError = .init(stream.currentLocation);
                try local_err.addChild(allocator, &err.msg);
                try local_err.withContext(allocator, "optionMaybe");
                break :blk Result(?Value).failure(local_err, err.rest);
            }
        },
    };
}

pub fn optional(stream: Stream, allocator: std.mem.Allocator, state: State, comptime Value: type, parser: anytype) anyerror!Result(void) {
    const r = try runParser(stream, allocator, state, Value, parser);
    return switch (r) {
        .Result => |res| Result(void).success(void{}, res.rest),
        .Error => |err| blk: {
            if (stream.diff(err.rest).len == 0) {
                err.msg.deinit(allocator);
                break :blk Result(void).success(void{}, err.rest);
            } else {
                var local_err: ParseError = .init(stream.currentLocation);
                try local_err.addChild(allocator, &err.msg);
                try local_err.withContext(allocator, "optional");
                break :blk Result(?Value).failure(local_err, err.rest);
            }
        },
    };
}

pub fn sepBy(stream: Stream, allocator: std.mem.Allocator, state: State, comptime PValue: type, parser: anytype, comptime SValue: type, sep: anytype) anyerror!Result([]PValue) {
    var array = std.ArrayList(PValue).init(allocator);
    var s = stream;

    switch (try runParser(s, allocator, state, PValue, parser)) {
        .Result => |res| {
            try array.append(res.value);
            s = res.rest;
        },
        .Error => |err| {
            err.msg.deinit(allocator);
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
                err.msg.deinit(allocator);
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
                var local_error: ParseError = .init(s.currentLocation);
                try local_error.addChild(allocator, &err.msg);
                try local_error.withContext(allocator, "sepBy");
                return Result([]PValue).failure(local_error, err.rest);
            },
        }
    }

    return Result([]PValue).success(try array.toOwnedSlice(), s);
}

pub fn sepBy1(stream: Stream, allocator: std.mem.Allocator, state: State, comptime PValue: type, parser: anytype, comptime SValue: type, sep: anytype) anyerror!Result([]PValue) {
    var array = std.ArrayList(PValue).init(allocator);
    var s = stream;

    switch (try runParser(s, allocator, state, PValue, parser)) {
        .Result => |res| {
            try array.append(res.value);
            s = res.rest;
        },
        .Error => |err| {
            array.deinit();
            var local_error: ParseError = .init(s.currentLocation);
            try local_error.addChild(allocator, &err.msg);
            try local_error.withContext(allocator, "sepBy1");
            return Result([]PValue).failure(local_error, err.rest);
        },
    }

    while (run: {
        switch (try runParser(s, allocator, state, SValue, sep)) {
            .Result => |res| {
                s = res.rest;
                break :run true;
            },
            .Error => |err| {
                err.msg.deinit(allocator);
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
                var local_error: ParseError = .init(s.currentLocation);
                try local_error.addChild(allocator, &err.msg);
                try local_error.withContext(allocator, "sepBy1");
                return Result([]PValue).failure(local_error, err.rest);
            },
        }
    }

    return Result([]PValue).success(try array.toOwnedSlice(), s);
}

pub fn notFollowedBy(stream: Stream, allocator: std.mem.Allocator, state: State, comptime PValue: type, parser: anytype, comptime FValue: type, follow: anytype) anyerror!Result(PValue) {
    switch (try runParser(stream, allocator, state, PValue, parser)) {
        .Result => |res| {
            switch (try runParser(res.rest, allocator, state, FValue, follow)) {
                .Result => return Result(PValue).failure(ParseError.init(res.rest.currentLocation), res.rest), // TODO: Improve message
                .Error => |err| {
                    err.msg.deinit(allocator);
                    return Result(PValue).success(res.value, res.rest);
                },
            }
        },
        .Error => |err| {
            var local_error: ParseError = .init(stream.currentLocation);
            try local_error.addChild(allocator, &err.msg);
            try local_error.withContext(allocator, "notFollowedBy");
            return Result(PValue).failure(local_error, err.rest);
        },
    }
}

fn lscan(stream: Stream, allocator: std.mem.Allocator, state: State, comptime PValue: type, parser: anytype, comptime OValue: type, op: anytype) anyerror!Result(PValue) {
    return switch (try runParser(stream, allocator, state, PValue, parser)) {
        .Result => |res| lrest(res.rest, allocator, state, PValue, parser, OValue, op, res.value),
        .Error => |err| blk: {
            var local_error: ParseError = .init(stream.currentLocation);
            try local_error.addChild(allocator, &err.msg);
            try local_error.withContext(allocator, "lscan");
            break :blk Result(PValue).failure(local_error, err.rest);
        },
    };
}

fn lrest(stream: Stream, allocator: std.mem.Allocator, state: State, comptime PValue: type, parser: anytype, comptime OValue: type, op: anytype, x: PValue) anyerror!Result(PValue) {
    switch (try runParser(stream, allocator, state, OValue, op)) {
        .Result => |res| {
            const operator_fnc: *const fn (std.mem.Allocator, PValue, PValue) anyerror!PValue = res.value;
            switch (try lscan(res.rest, allocator, state, PValue, parser, OValue, op)) {
                .Result => |res2| return Result(PValue).success(try operator_fnc(allocator, x, res2.value), res2.rest),
                .Error => |err| {
                    err.msg.deinit(allocator);
                },
            }
        },
        .Error => |err| {
            err.msg.deinit(allocator);
        },
    }
    return Result(PValue).success(x, stream);
}

pub fn chainl1(stream: Stream, allocator: std.mem.Allocator, state: State, comptime PValue: type, parser: anytype, comptime OValue: type, op: anytype) anyerror!Result(PValue) {
    return switch (try lscan(stream, allocator, state, PValue, parser, OValue, op)) {
        .Result => |res| lrest(res.rest, allocator, state, PValue, parser, OValue, op, res.value),
        .Error => |err| blk: {
            var local_error: ParseError = .init(stream.currentLocation);
            try local_error.addChild(allocator, &err.msg);
            try local_error.withContext(allocator, "chainl1");
            break :blk Result(PValue).failure(local_error, err.rest);
        },
    };
}

pub fn chainl(stream: Stream, allocator: std.mem.Allocator, state: State, comptime PValue: type, parser: anytype, comptime OValue: type, op: anytype, x: PValue) anyerror!Result(PValue) {
    switch (try chainl1(stream, allocator, state, PValue, parser, OValue, op)) {
        .Result => |res| return Result(PValue).success(res.value, res.rest),
        .Error => |err| {
            err.msg.deinit(allocator);
            return Result(PValue).success(x, err.rest);
        },
    }
}

pub fn untilNoAlloc(stream: Stream, allocator: std.mem.Allocator, state: State, parser: anytype, comptime EValue: type, end: anytype) anyerror!Result([]const u8) {
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
                var local_error: ParseError = .init(stream.currentLocation);
                try local_error.addChild(allocator, &err.msg);
                try local_error.withContext(allocator, "untilNoAlloc");
                return Result([]const u8).failure(local_error, err.rest);
            },
        }
    }
    return Result([]const u8).success(stream.diff(s), s);
}

pub fn until(stream: Stream, allocator: std.mem.Allocator, state: State, comptime PValue: type, parser: anytype, comptime EValue: type, end: anytype) anyerror!Result([]PValue) {
    var array = std.ArrayList(PValue).init(allocator);

    var s = stream;
    while (blk: {
        switch (try runParser(s, allocator, state, EValue, end)) {
            .Result => |res| {
                s = res.rest;
                break :blk false;
            },
            .Error => |err| {
                err.msg.deinit(allocator);
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
                var local_error: ParseError = .init(stream.currentLocation);
                try local_error.addChild(allocator, &err.msg);
                try local_error.withContext(allocator, "until");
                return Result([]PValue).failure(local_error, err.rest);
            },
        }
    }
    return Result([]PValue).success(try array.toOwnedSlice(), s);
}
