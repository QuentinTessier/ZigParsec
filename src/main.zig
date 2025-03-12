const std = @import("std");
const Parser = @import("Parser.zig");

pub fn main() !void {
    var instance: std.heap.DebugAllocator(.{}) = .init;
    defer _ = instance.deinit();

    const allocator = instance.allocator();

    const stream: Parser.Stream = .init("", null);
    const state: Parser.State = .{};

    switch (try Parser.Combinator.many(stream, allocator, state, u8, Parser.Char.alpha)) {
        .Error => |err| {
            try err.msg.print(stream, std.io.getStdOut().writer().any(), true);
            err.msg.deinit(allocator);
        },
        .Result => |res| {
            std.log.info("|{s}|", .{res.value});
            allocator.free(res.value);
        },
    }
}

test "many no input" {
    const stream: Parser.Stream = .init("", "test");
    const state: Parser.State = .{};

    const res = try Parser.Combinator.many(stream, std.testing.allocator, state, u8, .{ Parser.Char.symbol, .{'a'} });
    try std.testing.expect(res == .Result);
    try std.testing.expectEqual(res.Result.value.len, 0);
    try std.testing.expect(res.Result.rest.isEOF());
}
