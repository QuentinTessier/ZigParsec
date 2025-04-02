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

const data =
    \\{
    \\      "name": "Title",
    \\      "value": "Name",
    \\      "posX": 20
    \\}
;

pub const Data = struct {
    name: []const u8,
    value: []const u8,
    posX: u32,
};

pub const U = union(enum) {
    a: i32,
    b: i32,
};

pub fn isSameActiveTag(a: anytype, b: @TypeOf(a)) bool {
    const T = @TypeOf(a);
    comptime std.debug.assert(@typeInfo(T) == .@"union" and @typeInfo(T).@"union".tag_type != null);

    return std.meta.activeTag(a) == std.meta.activeTag(b);
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

    // const input = "";
    // var err: Ascii.AsciiError = undefined;
    // const rest, const value = (try parserIf(input, arena.allocator())).unwrap(&err) orelse {
    //     std.log.err("Error : {any} : {any}", .{ getLocation(input, err.input), err.err });
    //     return;
    // };

    // std.log.info("{c} : {s}", .{ value, rest });
    const a: Data = undefined;
    const b: Data = undefined;
    std.log.info("{}", .{isSameActiveTag(a, b)});
}
