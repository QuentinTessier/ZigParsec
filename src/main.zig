const std = @import("std");
const Parser = @import("Parser.zig");

const ExprParser = @import("examples/Expression.zig");

pub fn main() !void {
    var instance: std.heap.DebugAllocator(.{}) = .init;
    defer _ = instance.deinit();

    const allocator = instance.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parser_allocator = arena.allocator();

    const stream: Parser.Stream = .init("1 + 1", null);
    const state: Parser.State = .{
        .auto_eat_whitespace = true,
    };

    switch (try ExprParser.expression(stream, parser_allocator, state)) {
        .Error => |err| {
            try err.msg.print(stream, std.io.getStdOut().writer().any(), true);
        },
        .Result => |res| {
            res.value.dump();
        },
    }
}
