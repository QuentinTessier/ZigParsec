const std = @import("std");
const Parser = @import("Parser.zig").Parser(u32);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var userState: u32 = 0;
    const s = Parser.Stream.init("(abc)", null);

    switch (try Parser.Combinator.between(
        s,
        allocator,
        &userState,
        .{ u8, []const u8, u8 },
        .{ .parser = Parser.Char.symbol, .args = .{'('} },
        .{ .parser = Parser.Char.string, .args = .{"abc"} },
        .{ .parser = Parser.Char.symbol, .args = .{')'} },
    )) {
        .Result => |res| {
            std.log.info("Success with {s}", .{res.value});
            //allocator.free(res.value);
        },
        .Error => |err| {
            std.log.err("{s}", .{err.msg.items});
            err.msg.deinit();
        },
    }
}
