const std = @import("std");
const ParseError = @import("error/Error.zig").ParseError;

// TODO: Improved return type to make it aware of backtracking result, add safe and unsafe function to unwrap value out of the Result type
pub fn Result(comptime Stream: type, comptime Value: type, comptime Err: type) type {
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

        pub fn stream(self: *const @This()) Stream {
            return switch (self.*) {
                .Result => |val| val.rest,
                .Error => |val| val.rest,
            };
        }
    };
}

// TODO: Use the zig's 0.16.0 Reader interface instead of a custom type. This mean figuring out how to get a "checkpoint" output of a reader.
pub fn ParserStream(comptime S: type) type {
    return struct {
        data: S,
        total_size: usize,

        pub fn init(data: S) @This() {
            return .{
                .data = data,
                .total_size = data.len,
            };
        }

        pub fn consume(self: *const @This(), n: usize) @This() {
            return .{
                .data = self.data[n..],
                .total_size = self.total_size,
            };
        }

        pub fn checkpoint(self: *const @This()) usize {
            return self.total_size - self.data.len;
        }
    };
}

pub const Utf8Error = ParseError(ParserStream([]const u8), usize, u8);

pub fn Error(comptime E: type) type {
    return union(enum) {
        backtrack: E,
        fatal: E,
    };
}

pub fn Parser(comptime S: type, comptime V: type, comptime E: type) type {
    return *const fn (S, std.mem.Allocator) anyerror!Result(S, V, Error(E));
}

pub fn ParserUtf8(comptime V: type) type {
    return Parser(ParserStream([]const u8), V, Utf8Error);
}

pub fn Utf8Atom(comptime C: u8) ParserUtf8(u8) {
    return struct {
        const R = Result(ParserStream([]const u8), u8, Error(Utf8Error));

        pub fn inline_parser(stream: ParserStream([]const u8), allocator: std.mem.Allocator) anyerror!R {
            const checkpoint = stream.checkpoint();
            if (stream.data.len == 0) {
                var err: Utf8Error = .empty;
                _ = err.end_of_input().append(stream, checkpoint);
                return R.failure(.{ .backtrack = err }, stream);
            } else if (stream.data[0] == C) {
                return R.success(C, stream.consume(1));
            } else {
                var err: Utf8Error = .empty;
                _ = err
                    .unexpected(.{ .unexpected_token = stream.data[0] })
                    .expected(allocator, .{ .expected_token = C })
                    .append(stream.consume(1), checkpoint);
                return R.failure(.{ .backtrack = err }, stream.consume(1));
            }
        }
    }.inline_parser;
}

pub fn Utf8String(comptime S: []const u8) ParserUtf8([]const u8) {
    return struct {
        const R = Result(ParserStream([]const u8), []const u8, Error(Utf8Error));

        pub fn inline_parser(stream: ParserStream([]const u8), allocator: std.mem.Allocator) anyerror!R {
            const checkpoint = stream.checkpoint();
            if (stream.data.len == 0) {
                var err: Utf8Error = .empty;
                _ = err.end_of_input().append(stream, checkpoint);
                return R.failure(.{ .backtrack = err }, stream);
            } else if (stream.data.len < S.len) {
                var err: Utf8Error = .empty;
                _ = err
                    .unexpected(.{ .unexpected_range = stream.data[0..] })
                    .expected(allocator, .{ .expected_range = S })
                    .append(stream.consume(stream.data.len), checkpoint);
                return R.failure(.{ .backtrack = err }, stream.consume(stream.data.len));
            } else if (std.mem.eql(u8, stream.data[0..S.len], S)) {
                return R.success(S, stream.consume(S.len));
            } else {
                var err: Utf8Error = .empty;
                _ = err
                    .unexpected(.{ .unexpected_range = stream.data[0..S.len] })
                    .expected(allocator, .{ .expected_range = S })
                    .append(stream.consume(1), checkpoint);
                return R.failure(.{ .backtrack = err }, stream.consume(S.len));
            }
        }
    }.inline_parser;
}

pub const a = Utf8Atom('a');
pub const b = Utf8Atom('b');
pub const string = Utf8String("string");

pub fn Alt(comptime S: type, comptime V: type, comptime E: type, comptime Parsers: []const Parser(S, V, E)) Parser(S, V, E) {
    return struct {
        const R = Result(S, V, Error(E));

        pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
            const checkpoint = stream.checkpoint();

            var last_err: ?E = .empty;

            inline for (Parsers) |parser| {
                const result = try parser(stream, allocator);
                switch (result) {
                    .Result => return result,
                    .Error => |e| switch (e.msg) {
                        .fatal => return result,
                        .backtrack => |inner| {
                            if (last_err != null) {
                                _ = last_err.?.@"or"(allocator, &inner);
                            } else {
                                last_err = inner;
                            }
                        },
                    },
                }
            }

            _ = last_err.?.append(stream, checkpoint);
            return R.failure(.{
                .backtrack = last_err.?,
            }, stream);
        }
    }.inline_parser;
}

pub const alt_a_b = Alt(ParserStream([]const u8), u8, Utf8Error, &.{ a, b });

// pub fn Many(comptime S: type, comptime V: type, comptime P: *const fn (S, std.mem.Allocator) anyerror!Result(S, V, Error(V))) ParserUtf8([]u8, u8) {
//     return struct {
//         const R = Result([]const u8, []u8, Error(u8));

//         pub fn inline_parser(stream: []const u8, allocator: std.mem.Allocator) anyerror!R {
//             var result: std.array_list.Aligned(V, null) = .empty;
//             var s = stream;
//             while (true) {
//                 const r = try @call(.auto, P, .{ s, allocator });
//                 switch (r) {
//                     .Result => |res| {
//                         s = res.rest;
//                         try result.append(allocator, res.value);
//                     },
//                     .Error => |err| {
//                         if (err.msg == .backtrack) {
//                             break;
//                         } else {
//                             return R.failure(err.msg, err.rest);
//                         }
//                     },
//                 }
//             }
//             return R.success(try result.toOwnedSlice(allocator), s);
//         }
//     }.inline_parser;
// }

// const many_a = Many([]const u8, u8, a);

const ResolvedSpan = struct {
    line: usize,
    col: usize,
    line_start: usize,
    line_end: usize,
    start: usize,
    end: usize,
};

fn resolve_span(err: Utf8Error, stream: ParserStream([]const u8)) ResolvedSpan {
    const src = stream.data;
    const offset = err.start orelse 0;

    var line: usize = 1;
    var col: usize = 1;
    var line_start: usize = 0;

    var i: usize = 0;
    while (i < offset and i < src.len) : (i += 1) {
        if (src[i] == '\n') {
            line += 1;
            col = 1;
            line_start = i + 1;
        } else {
            col += 1;
        }
    }

    var line_end = line_start;
    while (line_end < src.len and src[line_end] != '\n') : (line_end += 1) {}

    return .{
        .line = line,
        .col = col,
        .line_start = line_start,
        .line_end = line_end,
        .start = offset,
        .end = err.end orelse offset,
    };
}

fn render_source_line(src: []const u8, span: ResolvedSpan) void {
    const line_text = src[span.line_start..span.line_end];
    const err_len = @max(1, span.end -| span.start);

    std.debug.print("  {d:>4} | {s}\n", .{ span.line, line_text });
    std.debug.print("       | ", .{});
    for (0..span.col - 1) |_| {
        std.debug.print(" ", .{});
    }

    for (0..err_len) |_| {
        std.debug.print("^", .{});
    }
}

pub fn render_error(stream: ParserStream([]const u8), stream_name: ?[]const u8, err: Utf8Error) void {
    const span = resolve_span(err, stream);

    std.debug.print("{s} --> line {}, col {}\n", .{ if (stream_name) |s| s else "null", span.line, span.col });
    render_source_line(stream.data, span);

    if (err._unexpected) |unexpected| {
        switch (unexpected) {
            .unexpected_token => |t| std.debug.print(" unexpected `{c}`", .{t}),
            .unexpected_range => |t| std.debug.print(" unexpected `{s}`", .{t}),
            .unexpected_message => |t| std.debug.print(" unexpected `{s}`", .{t}),
            .end_of_input => std.debug.print(" unexpected end of input", .{}),
            else => {},
        }
    }

    if (err._expected.items.len > 0) {
        std.debug.print(", expected ", .{});
        for (err._expected.items, 0..) |expected, i| {
            if (i > 0) std.debug.print(" or ", .{});
            switch (expected) {
                .expected_token => |t| std.debug.print("`{c}`", .{t}),
                .expected_range => |t| std.debug.print("`{s}`", .{t}),
                .expected_message => |t| std.debug.print("`{s}`", .{t}),
                else => {},
            }
        }
    }
    std.debug.print("\n", .{});
}

pub fn main() !void {
    var instance: std.heap.DebugAllocator(.{}) = .init;
    defer _ = instance.deinit();

    const allocator = instance.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parser_allocator = arena.allocator();

    const stream: ParserStream([]const u8) = .init("b");

    // TODO: Provide a `parse` function that handles the creation of the arena
    switch (try alt_a_b(stream, parser_allocator)) {
        .Result => |r| {
            std.log.debug("Success: {any}", .{r});
            // allocator.free(r.value);
        },
        .Error => |e| {
            render_error(stream, "<input>", if (e.msg == .backtrack) e.msg.backtrack else e.msg.fatal);
            //std.log.debug("Failure: {any}", .{e});
        },
    }
}
