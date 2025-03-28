const std = @import("std");
const builtin = @import("builtin");
const Parser = @import("parser.zig");

fn TestParser(comptime T: type) type {
    return Parser.ParserFn(Parser.CharInput, T, Parser.Error);
}

pub const symbolA = Parser.Prim.Symbol(Parser.CharInput, u8, Parser.Error, 'a');
pub const symbolB = Parser.Prim.Symbol(Parser.CharInput, u8, Parser.Error, 'b');
pub const symbolC = Parser.Prim.Symbol(Parser.CharInput, u8, Parser.Error, 'c');

pub const choiceABC = Parser.Combinator.Choice(Parser.CharInput, u8, Parser.Error, &.{
    symbolA,
    symbolB,
    symbolC,
});

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const gpa, const is_debug = gpa: {
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();

    const input: Parser.CharInput = .init("daaab");
    var err: Parser.Error = undefined;
    const rest, const value = (try choiceABC(input, arena.allocator())).unwrap(&err) orelse {
        std.log.err("Error", .{});
        return;
    };
    std.log.info("{c} : {s}", .{ value, rest.data });
}
