const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("ZigParsec", .{
        .root_source_file = .{ .path = "src/Parser.zig" },
    });
}
