const std = @import("std");
const builtin = @import("builtin");
const Parser = @import("parser.zig");

pub const symbolA = Parser.Prim.Symbol([]const u8, Parser.Error([]const u8), @as(u8, 'a'));
pub const symbolB = Parser.Prim.Symbol([]const u8, Parser.Error([]const u8), @as(u8, 'b'));
pub const symbolC = Parser.Prim.Symbol([]const u8, Parser.Error([]const u8), @as(u8, 'c'));
pub const manyA = Parser.Combinator.Many1([]const u8, Parser.Error([]const u8), symbolA);
pub const sepByB = Parser.Combinator.SepBy([]const u8, Parser.Error([]const u8), symbolA, symbolB);

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn Many1(comptime _: type, comptime _: type, comptime P: anytype) type {
    return struct {
        pub const T: type = Parser.ParsedType(@TypeOf(P));
    };
}

pub const Location = struct {
    line: usize,
    column: usize,
};

pub fn getLocation(fullSource: []const u8, at: []const u8) Location {
    std.debug.assert(fullSource.len >= at.len);

    const before = fullSource[0 .. fullSource.len - at.len];

    const line = std.mem.count(u8, before, "\n");
    var column: usize = before.len;
    if (std.mem.lastIndexOfScalar(u8, before, '\n')) |lastLine| {
        column = before.len - lastLine;
    }

    return Location{
        .line = line,
        .column = column,
    };
}

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

    const input = "ababababa";
    var err: Parser.Error([]const u8) = undefined;
    const rest, const value = (try sepByB(input, arena.allocator())).unwrap(&err) orelse {
        std.log.err("Error : {s} : {any}", .{ err.@"1".fn_name, getLocation(input, err.@"0") });
        return;
    };

    std.log.info("{s} : {s}", .{ value, rest });
}
