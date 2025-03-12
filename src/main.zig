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
