const std = @import("std");
const builtin = @import("builtin");
const Parser = @import("parser.zig");
const Ascii = @import("ascii.zig");

const Char = Parser.Prim.Char([]const u8, Parser.Error([]const u8));
const Comb = Parser.Combinator.Comb([]const u8, Parser.Error([]const u8));

pub const parserIf = Ascii.String("if");
pub const Base64 = Ascii.Digit(64);

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

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

    const input = "";
    var err: Parser.Error([]const u8) = undefined;
    _, const value = (try parserIf(input, arena.allocator())).unwrap(&err) orelse {
        std.log.err("Error : {any} : {any}", .{ getLocation(input, err.input), err });
        return;
    };
    std.log.info("{s}", .{value});
}
