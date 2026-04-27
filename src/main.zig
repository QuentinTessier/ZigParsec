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

pub const Checkpoint = enum(usize) {
    begin = 0,
    end = std.math.maxInt(usize),
    _,
};

pub const Utf8ReaderStream = struct {
    reader: ?*std.Io.Reader = null,
    allocator: std.mem.Allocator,
    bytes: *std.array_list.Aligned(u8, null),
    offset: usize,

    pub fn is_partial(self: *const Utf8ReaderStream) ?*std.Io.Reader {
        return self.reader;
    }

    pub fn init_fixed(allocator: std.mem.Allocator, bytes: *std.array_list.Aligned(u8, null)) Utf8ReaderStream {
        return .{
            .allocator = allocator,
            .bytes = bytes,
            .offset = 0,
        };
    }

    pub fn init_partial(allocator: std.mem.Allocator, reader: *std.Io.Reader, bytes: *std.array_list.Aligned(u8, null)) Utf8ReaderStream {
        return .{
            .allocator = allocator,
            .reader = reader,
            .bytes = bytes,
            .offset = 0,
        };
    }

    pub fn peek(self: *const Utf8ReaderStream) std.Io.Reader.AppendExactError!u8 {
        if (self.offset < self.bytes.items.len) {
            return self.bytes.items[self.offset];
        }

        if (self.reader) |reader| {
            try reader.appendExact(self.allocator, self.bytes, 1);
            return self.bytes.items[self.offset];
        }
        return error.EndOfStream;
    }

    pub fn peek_slice(self: *const Utf8ReaderStream, n: usize) ![]const u8 {
        const available = self.bytes.items.len -| self.offset;
        if (available >= n) {
            return self.bytes.items[self.offset .. self.offset + n];
        }

        if (self.reader) |reader| {
            const needed = n - available;
            try reader.appendExact(self.allocator, self.bytes, needed);
            return self.bytes.items[self.offset .. self.offset + n];
        }
        return self.bytes.items[self.offset .. self.offset + available];
    }

    pub fn consume(self: *const Utf8ReaderStream, n: usize) Utf8ReaderStream {
        return .{
            .reader = self.reader,
            .bytes = self.bytes,
            .offset = self.offset + n,
            .allocator = self.allocator,
        };
    }

    pub fn checkpoint(self: *const Utf8ReaderStream) Checkpoint {
        return @enumFromInt(self.offset);
    }

    pub fn backtrack(self: *const Utf8ReaderStream, c: Checkpoint) Utf8ReaderStream {
        return .{
            .reader = self.reader,
            .bytes = self.bytes,
            .offset = switch (c) {
                .begin => 0,
                .end => self.bytes.items.len - 1,
                else => @intFromEnum(c),
            },
            .allocator = self.allocator,
        };
    }
};

pub const Utf8Error = ParseError(Utf8ReaderStream, Checkpoint, u8);

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
    return Parser(Utf8ReaderStream, V, Utf8Error);
}

pub fn Utf8Atom(comptime C: u8) ParserUtf8(u8) {
    return struct {
        const R = Result(Utf8ReaderStream, u8, Error(Utf8Error));

        pub fn inline_parser(stream: Utf8ReaderStream, allocator: std.mem.Allocator) anyerror!R {
            var s = stream;
            const checkpoint = stream.checkpoint();
            const byte = s.peek() catch |e| switch (e) {
                error.EndOfStream => {
                    var err: Utf8Error = .empty;
                    _ = err.end_of_input().append(stream, checkpoint);
                    return R.failure(.{ .backtrack = err }, stream);
                },
                else => return e,
            };
            if (byte == C) {
                return R.success(C, stream.consume(1));
            } else {
                var err: Utf8Error = .empty;
                _ = err
                    .unexpected(.{ .unexpected_token = byte })
                    .expected(allocator, .{ .expected_token = C })
                    .append(s.consume(1), checkpoint);
                return R.failure(.{ .backtrack = err }, stream);
            }
        }
    }.inline_parser;
}

pub fn Utf8String(comptime S: []const u8) ParserUtf8([]const u8) {
    return struct {
        const R = Result(Utf8ReaderStream, []const u8, Error(Utf8Error));

        pub fn inline_parser(stream: Utf8ReaderStream, allocator: std.mem.Allocator) anyerror!R {
            const checkpoint = stream.checkpoint();
            var s = stream;

            const bytes = s.peek_slice(S.len) catch |e| switch (e) {
                error.EndOfStream => {
                    std.log.err("Shouldn't enter here", .{});
                    var err: Utf8Error = .empty;
                    _ = err.end_of_input().append(stream, checkpoint);
                    return R.failure(.{ .backtrack = err }, stream);
                },
                else => return e,
            };

            if (bytes.len < S.len) {
                var err: Utf8Error = .empty;
                _ = err
                    .unexpected(.{ .unexpected_range = bytes })
                    .expected(allocator, .{ .expected_range = S })
                    .append(stream.consume(bytes.len), checkpoint);
                return R.failure(.{ .backtrack = err }, stream);
            } else if (std.mem.eql(u8, bytes, S)) {
                return R.success(S, stream.consume(S.len));
            } else {
                var err: Utf8Error = .empty;
                _ = err
                    .unexpected(.{ .unexpected_range = bytes })
                    .expected(allocator, .{ .expected_range = S })
                    .append(stream.consume(bytes.len), checkpoint);
                return R.failure(.{ .backtrack = err }, stream.consume(S.len));
            }
        }
    }.inline_parser;
}

pub const a = Utf8Atom('a');
// pub const b = Utf8Atom('b');
pub const string = Utf8String("string");

// pub fn Alt(comptime S: type, comptime V: type, comptime E: type, comptime Parsers: []const Parser(S, V, E)) Parser(S, V, E) {
//     return struct {
//         const R = Result(S, V, Error(E));

//         pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
//             const checkpoint = stream.checkpoint();

//             var last_err: ?E = .empty;

//             inline for (Parsers) |parser| {
//                 const result = try parser(stream, allocator);
//                 switch (result) {
//                     .Result => return result,
//                     .Error => |e| switch (e.msg) {
//                         .fatal => return result,
//                         .backtrack => |inner| {
//                             if (last_err != null) {
//                                 _ = last_err.?.@"or"(allocator, &inner);
//                             } else {
//                                 last_err = inner;
//                             }
//                         },
//                     },
//                 }
//             }

//             _ = last_err.?.append(stream, checkpoint);
//             return R.failure(.{
//                 .backtrack = last_err.?,
//             }, stream);
//         }
//     }.inline_parser;
// }

// pub const alt_a_b = Alt(ParserStream([]const u8), u8, Utf8Error, &.{ a, b });

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

fn resolve_span(err: Utf8Error, stream: Utf8ReaderStream) ResolvedSpan {
    const src = stream.bytes.items;
    const offset = err.start orelse .begin;

    var line: usize = 1;
    var col: usize = 1;
    var line_start: usize = 0;

    var i: usize = 0;
    while (i < @intFromEnum(offset) and i < src.len) : (i += 1) {
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
        .start = @intFromEnum(offset),
        .end = @intFromEnum(err.end orelse offset),
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

pub fn render_error(stream: Utf8ReaderStream, stream_name: ?[]const u8, err: Utf8Error) void {
    const span = resolve_span(err, stream);

    std.debug.print("{s} --> line {}, col {}\n", .{ if (stream_name) |s| s else "null", span.line, span.col });
    render_source_line(stream.bytes.items, span);

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

    //var fixed = std.Io.Reader.fixed("stran");

    var content: std.array_list.Aligned(u8, null) = .empty;
    //const stream: Utf8ReaderStream = .init_partial(allocator, &fixed, &content);
    try content.appendSlice(allocator, "stran");
    const stream: Utf8ReaderStream = .init_fixed(allocator, &content);

    defer content.deinit(allocator);

    // TODO: Provide a `parse` function that handles the creation of the arena
    switch (try string(stream, parser_allocator)) {
        .Result => |r| {
            std.log.debug("Success: {any}", .{r});
            // allocator.free(r.value);
        },
        .Error => |e| {
            render_error(stream, "<input>", if (e.msg == .backtrack) e.msg.backtrack else e.msg.fatal);
            //std.log.debug("Failure: {any} : {s}", .{ e, e.rest.bytes.items });
        },
    }
}
