const std = @import("std");
const Utf8Stream = @import("utf8/stream.zig").Stream;
const Utf8Char = @import("utf8/char.zig");
const Utf8Comb = @import("utf8/combinator.zig");

// const ResolvedSpan = struct {
//     line: usize,
//     col: usize,
//     line_start: usize,
//     line_end: usize,
//     start: usize,
//     end: usize,
// };

// fn resolve_span(err: Utf8Error, stream: Utf8ReaderStream) ResolvedSpan {
//     const src = stream.bytes.items;
//     const offset = err.start orelse .begin;

//     var line: usize = 1;
//     var col: usize = 1;
//     var line_start: usize = 0;

//     var i: usize = 0;
//     while (i < @intFromEnum(offset) and i < src.len) : (i += 1) {
//         if (src[i] == '\n') {
//             line += 1;
//             col = 1;
//             line_start = i + 1;
//         } else {
//             col += 1;
//         }
//     }

//     var line_end = line_start;
//     while (line_end < src.len and src[line_end] != '\n') : (line_end += 1) {}

//     return .{
//         .line = line,
//         .col = col,
//         .line_start = line_start,
//         .line_end = line_end,
//         .start = @intFromEnum(offset),
//         .end = @intFromEnum(err.end orelse offset),
//     };
// }

// fn render_source_line(src: []const u8, span: ResolvedSpan) void {
//     const line_text = src[span.line_start..span.line_end];
//     const err_len = @max(1, span.end -| span.start);

//     std.debug.print("  {d:>4} | {s}\n", .{ span.line, line_text });
//     std.debug.print("       | ", .{});
//     for (0..span.col - 1) |_| {
//         std.debug.print(" ", .{});
//     }

//     for (0..err_len) |_| {
//         std.debug.print("^", .{});
//     }
// }

// pub fn render_error(stream: Utf8ReaderStream, stream_name: ?[]const u8, err: Utf8Error) void {
//     const span = resolve_span(err, stream);

//     std.debug.print("{s} --> line {}, col {}\n", .{ if (stream_name) |s| s else "null", span.line, span.col });
//     render_source_line(stream.bytes.items, span);

//     if (err._unexpected) |unexpected| {
//         switch (unexpected) {
//             .unexpected_token => |t| std.debug.print(" unexpected `{c}`", .{t}),
//             .unexpected_range => |t| std.debug.print(" unexpected `{s}`", .{t}),
//             .unexpected_message => |t| std.debug.print(" unexpected `{s}`", .{t}),
//             .end_of_input => std.debug.print(" unexpected end of input", .{}),
//             else => {},
//         }
//     }

//     if (err._expected.items.len > 0) {
//         std.debug.print(", expected ", .{});
//         for (err._expected.items, 0..) |expected, i| {
//             if (i > 0) std.debug.print(" or ", .{});
//             switch (expected) {
//                 .expected_token => |t| std.debug.print("`{c}`", .{t}),
//                 .expected_range => |t| std.debug.print("`{s}`", .{t}),
//                 .expected_message => |t| std.debug.print("`{s}`", .{t}),
//                 else => {},
//             }
//         }
//     }
//     std.debug.print("\n", .{});
// }

const a = Utf8Char.Char('a');
const b = Utf8Char.Char('b');
const value = Utf8Char.String("value");

const many_a = Utf8Comb.Many(u8, a);

const alt_a_b = Utf8Comb.Alt(u8, &.{ a, b });

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
    try content.appendSlice(allocator, "b");
    const stream: Utf8Stream = .fixed(allocator, &content);

    defer content.deinit(allocator);

    // TODO: Provide a `parse` function that handles the creation of the arena
    switch (try alt_a_b(stream, parser_allocator)) {
        .result => |r| {
            std.log.debug("Success: {any} : {s}", .{ r, r.rest.bytes.items[r.rest.offset..] });
            // allocator.free(r.value);
        },
        .@"error" => |e| {
            //render_error(stream, "<input>", if (e.msg == .backtrack) e.msg.backtrack else e.msg.fatal);
            std.log.debug("Failure: {any} : {s}", .{ e, e.rest.bytes.items });
        },
    }
}
