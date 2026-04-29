const std = @import("std");

const Stream = @import("stream.zig").Stream;
const ParseError = @import("error.zig").ParseError;
const Utf8Parser = @import("parser.zig").Utf8Parser;

const Result = @import("../parser/result.zig").Result;
const Error = @import("../parser/error.zig").Error;

pub fn any_char(stream: Stream, _: std.mem.Allocator) anyerror!Result(Stream, u8, ParseError) {
    const checkpoint = stream.checkpoint();
    const byte = stream.peek() catch |e| switch (e) {
        error.EndOfStream => {
            var err: ParseError = .empty;
            _ = err.end_of_input().append(stream, checkpoint);
            return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
        },
        else => return e,
    };

    return Result(Stream, u8, ParseError).success(byte, stream.consume(1));
}

pub fn digit(stream: Stream, allocator: std.mem.Allocator) anyerror!Result(Stream, u8, ParseError) {
    const checkpoint = stream.checkpoint();
    const byte = stream.peek() catch |e| switch (e) {
        error.EndOfStream => {
            var err: ParseError = .empty;
            _ = err.end_of_input().append(stream, checkpoint);
            return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
        },
        else => return e,
    };

    if (!std.ascii.isDigit(byte)) {
        var err: ParseError = .empty;
        _ = err.unexpected(.{ .unexpected_token = byte })
            .expected(
            allocator,
            .{
                .expected_message = " value in range [0 .. 9]",
            },
        );
        return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
    } else {
        return Result(Stream, u8, ParseError).success(byte, stream.consume(1));
    }
}

pub fn hex_digit(stream: Stream, allocator: std.mem.Allocator) anyerror!Result(Stream, u8, ParseError) {
    const checkpoint = stream.checkpoint();
    const byte = stream.peek() catch |e| switch (e) {
        error.EndOfStream => {
            var err: ParseError = .empty;
            _ = err.end_of_input().append(stream, checkpoint);
            return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
        },
        else => return e,
    };

    switch (byte) {
        '0'...'9', 'A'...'Z', 'a'...'z' => Result(Stream, u8, ParseError).success(byte, stream.consume(1)),
        else => blk: {
            var err: ParseError = .empty;
            _ = err.unexpected(.{ .unexpected_token = byte })
                .expected(
                allocator,
                .{
                    .expected_message = " value in range [0 .. 9, A .. Z, a .. z]",
                },
            );
            break :blk Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
        },
    }
}

pub fn oct_digit(stream: Stream, allocator: std.mem.Allocator) anyerror!Result(Stream, u8, ParseError) {
    const checkpoint = stream.checkpoint();
    const byte = stream.peek() catch |e| switch (e) {
        error.EndOfStream => {
            var err: ParseError = .empty;
            _ = err.end_of_input().append(stream, checkpoint);
            return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
        },
        else => return e,
    };

    switch (byte) {
        '0'...'8' => Result(Stream, u8, ParseError).success(byte, stream.consume(1)),
        else => blk: {
            var err: ParseError = .empty;
            _ = err.unexpected(.{ .unexpected_token = byte })
                .expected(
                allocator,
                .{
                    .expected_message = " value in range [0 .. 8]",
                },
            );
            break :blk Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
        },
    }
}

pub fn letter(stream: Stream, allocator: std.mem.Allocator) anyerror!Result(Stream, u8, ParseError) {
    const checkpoint = stream.checkpoint();
    const byte = stream.peek() catch |e| switch (e) {
        error.EndOfStream => {
            var err: ParseError = .empty;
            _ = err.end_of_input().append(stream, checkpoint);
            return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
        },
        else => return e,
    };

    if (!std.ascii.isAlphabetic(byte)) {
        var err: ParseError = .empty;
        _ = err.unexpected(.{ .unexpected_token = byte })
            .expected(
            allocator,
            .{
                .expected_message = " value in range [0 .. 9]",
            },
        );
        return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
    } else {
        return Result(Stream, u8, ParseError).success(byte, stream.consume(1));
    }
}

pub fn space(stream: Stream, allocator: std.mem.Allocator) anyerror!Result(Stream, u8, ParseError) {
    const checkpoint = stream.checkpoint();
    const byte = stream.peek() catch |e| switch (e) {
        error.EndOfStream => {
            var err: ParseError = .empty;
            _ = err.end_of_input().append(stream, checkpoint);
            return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
        },
        else => return e,
    };

    if (!std.ascii.isWhitespace(byte)) {
        var err: ParseError = .empty;
        _ = err.unexpected(.{ .unexpected_token = byte })
            .expected(
                allocator,
                .{ .expected_token = ' ' },
            )
            .expected(
                allocator,
                .{ .expected_token = '\t' },
            )
            .expected(
            allocator,
            .{ .expected_token = '\n' },
        );
        return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
    } else {
        return Result(Stream, u8, ParseError).success(byte, stream.consume(1));
    }
}

pub fn alpha_num(stream: Stream, allocator: std.mem.Allocator) anyerror!Result(Stream, u8, ParseError) {
    const checkpoint = stream.checkpoint();
    const byte = stream.peek() catch |e| switch (e) {
        error.EndOfStream => {
            var err: ParseError = .empty;
            _ = err.end_of_input().append(stream, checkpoint);
            return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
        },
        else => return e,
    };

    if (!std.ascii.isAlphanumeric(byte)) {
        var err: ParseError = .empty;
        _ = err.unexpected(.{ .unexpected_token = byte })
            .expected(
                allocator,
                .{ .expected_token = ' ' },
            )
            .expected(
                allocator,
                .{ .expected_token = '\t' },
            )
            .expected(
            allocator,
            .{ .expected_token = '\n' },
        );
        return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
    } else {
        return Result(Stream, u8, ParseError).success(byte, stream.consume(1));
    }
}

pub fn upper(stream: Stream, allocator: std.mem.Allocator) anyerror!Result(Stream, u8, ParseError) {
    const checkpoint = stream.checkpoint();
    const byte = stream.peek() catch |e| switch (e) {
        error.EndOfStream => {
            var err: ParseError = .empty;
            _ = err.end_of_input().append(stream, checkpoint);
            return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
        },
        else => return e,
    };

    if (!std.ascii.isUpper(byte)) {
        var err: ParseError = .empty;
        _ = err.unexpected(.{ .unexpected_token = byte })
            .expected(
                allocator,
                .{ .expected_token = ' ' },
            )
            .expected(
                allocator,
                .{ .expected_token = '\t' },
            )
            .expected(
            allocator,
            .{ .expected_token = '\n' },
        );
        return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
    } else {
        return Result(Stream, u8, ParseError).success(byte, stream.consume(1));
    }
}

pub fn lower(stream: Stream, allocator: std.mem.Allocator) anyerror!Result(Stream, u8, ParseError) {
    const checkpoint = stream.checkpoint();
    const byte = stream.peek() catch |e| switch (e) {
        error.EndOfStream => {
            var err: ParseError = .empty;
            _ = err.end_of_input().append(stream, checkpoint);
            return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
        },
        else => return e,
    };

    if (!std.ascii.isLower(byte)) {
        var err: ParseError = .empty;
        _ = err.unexpected(.{ .unexpected_token = byte })
            .expected(
                allocator,
                .{ .expected_token = ' ' },
            )
            .expected(
                allocator,
                .{ .expected_token = '\t' },
            )
            .expected(
            allocator,
            .{ .expected_token = '\n' },
        );
        return Result(Stream, u8, ParseError).failure(.{ .backtrack = err }, stream);
    } else {
        return Result(Stream, u8, ParseError).success(byte, stream.consume(1));
    }
}

pub fn Char(comptime C: u8) Utf8Parser(u8) {
    return struct {
        const R = Result(Stream, u8, ParseError);

        pub fn inline_parser(stream: Stream, allocator: std.mem.Allocator) anyerror!R {
            const checkpoint = stream.checkpoint();
            const byte = stream.peek() catch |e| switch (e) {
                error.EndOfStream => {
                    var err: ParseError = .empty;
                    _ = err.end_of_input().append(stream, checkpoint);
                    return R.failure(.{ .backtrack = err }, stream);
                },
                else => return e,
            };

            if (byte != C) {
                var err: ParseError = .empty;
                _ = err.unexpected(.{ .unexpected_token = byte })
                    .expected(allocator, .{ .expected_token = C })
                    .append(stream.consume(1), checkpoint);
                return R.failure(.{ .backtrack = err }, stream);
            } else {
                return R.success(C, stream.consume(1));
            }
        }
    }.inline_parser;
}

pub fn String(comptime S: []const u8) Utf8Parser([]const u8) {
    return struct {
        const R = Result(Stream, []const u8, ParseError);

        pub fn inline_parser(stream: Stream, allocator: std.mem.Allocator) anyerror!R {
            const checkpoint = stream.checkpoint();
            const bytes = stream.peek_slice(S.len) catch |e| switch (e) {
                error.EndOfStream => {
                    var err: ParseError = .empty;
                    _ = err.end_of_input().append(stream, checkpoint);
                    return R.failure(.{ .backtrack = err }, stream);
                },
                else => return e,
            };

            if (bytes.len != S.len or !std.mem.eql(u8, bytes, S)) {
                var err: ParseError = .empty;
                _ = err.unexpected(.{ .unexpected_range = bytes })
                    .expected(allocator, .{ .expected_range = S })
                    .append(stream.consume(1), checkpoint);
                return R.failure(.{ .backtrack = err }, stream);
            } else {
                return R.success(bytes, stream.consume(S.len));
            }
        }
    }.inline_parser;
}

pub fn Range(comptime Start: u8, comptime End: u8) Utf8Parser(u8) {
    return struct {
        const R = Result(Stream, u8, ParseError);

        pub fn inline_parser(stream: Stream, allocator: std.mem.Allocator) anyerror!R {
            const checkpoint = stream.checkpoint();
            const byte = stream.peek() catch |e| switch (e) {
                error.EndOfStream => {
                    var err: ParseError = .empty;
                    _ = err.end_of_input().append(stream, checkpoint);
                    return R.failure(.{ .backtrack = err }, stream);
                },
                else => return e,
            };

            switch (byte) {
                Start...End => return R.success(byte, stream.consume(1)),
                else => {
                    var err: ParseError = .empty;
                    _ = err.unexpected(.{ .unexpected_token = byte })
                        .expected(allocator, .{ .expected_message = "[" ++ [1]u8{Start} ++ "..." ++ [1]u8{End} ++ "]" })
                        .append(stream.consume(1), checkpoint);
                    return R.failure(.{ .backtrack = err }, stream);
                },
            }
        }
    }.inline_parser;
}

pub fn Satisfy(comptime Pred: *const fn (u8) bool, comptime message: ?[]const u8) Utf8Parser(u8) {
    return struct {
        const R = Result(Stream, u8, ParseError);

        pub fn inline_parser(stream: Stream, allocator: std.mem.Allocator) anyerror!R {
            const checkpoint = stream.checkpoint();
            const byte = stream.peek() catch |e| switch (e) {
                error.EndOfStream => {
                    var err: ParseError = .empty;
                    _ = err.end_of_input().append(stream, checkpoint);
                    return R.failure(.{ .backtrack = err }, stream);
                },
                else => return e,
            };

            if (Pred(byte)) {
                std.log.debug("Predicate is valid for {c}", .{byte});
                return R.success(byte, stream.consume(1));
            } else {
                std.log.debug("Predicate is invalid for {c}", .{byte});
                var err: ParseError = .empty;
                _ = err.unexpected(.{ .unexpected_token = byte })
                    .append(stream.consume(1), checkpoint);

                if (message) |msg| {
                    _ = err.expected(allocator, .{ .expected_message = msg });
                }
                return R.failure(.{ .backtrack = err }, stream);
            }
        }
    }.inline_parser;
}
