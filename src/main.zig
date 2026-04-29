const std = @import("std");
const Utf8Stream = @import("utf8/stream.zig").Stream;
const Utf8Error = @import("utf8/error.zig").ParseError;
const Utf8Char = @import("utf8/char.zig");

const Utf8Comb = @import("parser/combinator.zig").Combinator(Utf8Stream, Utf8Error);
const Lang = @import("utf8/language.zig");

const Result = @import("parser/result.zig").Result;
const Error = @import("parser/error.zig").Error;

pub const BinOp = enum {
    add,
    mul,
};

pub const Bin = struct {
    op: BinOp,
    left: *Expression,
    right: *Expression,
};

pub const Expression = union(enum) {
    lit: u8,
    bin: Bin,

    pub fn make_bin_operator_builder(comptime op: BinOp) *const fn (std.mem.Allocator, *Expression, *Expression) anyerror!*Expression {
        return struct {
            pub fn inline_builder(allocator: std.mem.Allocator, lhs: *Expression, rhs: *Expression) anyerror!*Expression {
                const n = try allocator.create(Expression);
                n.* = .{ .bin = .{
                    .op = op,
                    .left = lhs,
                    .right = rhs,
                } };
                return n;
            }
        }.inline_builder;
    }
};

const A = Utf8Char.Char('A');
const Open = Utf8Char.Char('(');
const Close = Utf8Char.Char(')');
const Comma = Utf8Char.Char(',');
const ManyA = Utf8Comb.Many(A);
const SeqBy = Utf8Comb.SepBy1(Comma, A);
const Between = Utf8Comb.Between(Open, Close, SeqBy);

fn print_expression_node(expr: *const Expression, id: *u32) u32 {
    const self_id = id.*;
    id.* += 1;

    switch (expr.*) {
        .lit => |v| std.debug.print("\tn{} [label=\"{c}\"]\n", .{ self_id, v }),
        .bin => |bin| {
            std.debug.print("\tn{} [label=\"{s}\" shape=ellipse]\n", .{ self_id, @tagName(bin.op) });
            const lhs_id = print_expression_node(bin.left, id);
            const rhs_id = print_expression_node(bin.right, id);

            std.debug.print("\tn{} -> n{} [label=\"lhs\"]\n", .{ self_id, lhs_id });
            std.debug.print("\tn{} -> n{} [label=\"rhs\"]\n", .{ self_id, rhs_id });
        },
    }
    return self_id;
}

pub fn print_expression_dot(expr: *const Expression) void {
    std.debug.print("digraph {{\n", .{});
    std.debug.print("\tnode [shape=box font_name=\"monospace\"]\n", .{});
    var id: u32 = 0;
    _ = print_expression_node(expr, &id);
    std.debug.print("}}\n", .{});
}

const Utf8Expression = @import("expression/generator.zig").ExpressionParserGenerator(Utf8Stream, *Expression, Utf8Error);

pub const Utf8ExpressionResult = Result(Utf8Stream, *Expression, Utf8Error);

pub fn term(stream: Utf8Stream, allocator: std.mem.Allocator) anyerror!Utf8ExpressionResult {
    const digit = try Utf8Char.digit(stream, allocator);
    return switch (digit) {
        .result => |r| blk: {
            const ptr = try allocator.create(Expression);
            ptr.* = .{ .lit = r.value };
            break :blk Utf8ExpressionResult.success(ptr, r.rest);
        },
        .@"error" => |e| Utf8ExpressionResult.failure(e.value, e.rest),
    };
}

pub const addP = Utf8Char.String("+");
pub const mulP = Utf8Char.String("*");

// Simply parses digit with '+' and '*' in between
const utf8_expression = Utf8Expression.build_expression_parser(.{
    .infix = &.{
        Utf8Expression.InfixOperator.new(addP, .{ .assoc = .left, .value = 60 }, Expression.make_bin_operator_builder(.add)),
        Utf8Expression.InfixOperator.new(mulP, .{ .assoc = .left, .value = 70 }, Expression.make_bin_operator_builder(.mul)),
    },
    .prefix = &.{},
    .postfix = &.{},
}, term);

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
    try content.appendSlice(allocator, "1+2*3*8+3*9");
    const stream: Utf8Stream = .fixed(allocator, &content);

    defer content.deinit(allocator);

    // TODO: Provide a `parse` function that handles the creation of the arena
    switch (try utf8_expression(stream, parser_allocator)) {
        .result => |r| {
            print_expression_dot(r.value);
            //std.log.debug("Success: {any} : {s}", .{ r, r.rest.bytes.items[r.rest.offset..] });
            // allocator.free(r.value);
        },
        .@"error" => |e| {
            //render_error(stream, "<input>", if (e.msg == .backtrack) e.msg.backtrack else e.msg.fatal);
            std.log.debug("Failure: {any} : {s}", .{ e, e.rest.bytes.items });
        },
    }
}
