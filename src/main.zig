const std = @import("std");
const Parser = @import("Parser.zig");
const Expression = @import("./examples/Expression.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var state: Parser.ZigParsecState = .{ .extensions = null };
    try Expression.makeStateExtension(allocator, &state);
    defer Expression.destroyStateExtension(allocator, &state);

    //const s = Parser.Stream.init("1+-2", null);
}
