const std = @import("std");

pub const Stream = @This();

pub const Location = struct {
    index: u64 = 0,
    line: u64 = 1,
    character: u64 = 1,

    pub fn format(self: Location, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return std.fmt.format(writer, "{}:{}({})", .{ self.line, self.character, self.index });
    }
};

data: []const u8,
label: ?[]const u8,
currentLocation: Location,

pub fn init(bytes: []const u8, label: ?[]const u8) Stream {
    return .{
        .data = bytes,
        .label = label,
        .currentLocation = .{},
    };
}

pub fn remaining(self: Stream) usize {
    return self.data.len - self.currentLocation.index;
}

pub fn diff(self: Stream, tail: Stream) []const u8 {
    //std.debug.assert(self.currentLocation.index >= tail.currentLocation.index);
    return self.data[self.currentLocation.index..tail.currentLocation.index];
}

pub fn peek(self: Stream, length: ?usize) []const u8 {
    const len: usize = if (length) |l| l else 1;
    const start = self.currentLocation.index;
    const end = @min(start + len, self.data.len);

    return self.data[start..end];
}

pub fn isEOF(self: Stream) bool {
    return self.currentLocation.index >= self.data.len;
}

pub fn eat(self: Stream, length: usize) Stream {
    const start = self.currentLocation.index;
    const next = @min(self.data.len, start + length);

    var new = self;

    var i = start;
    while (i < next) : (i += 1) {
        switch (self.data[i]) {
            '\n' => {
                new.currentLocation.line += 1;
                new.currentLocation.character = 1;
            },
            else => new.currentLocation.character += 1,
        }
    }
    new.currentLocation.index = i;

    return new;
}

pub fn format(self: Stream, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    return std.fmt.format(writer, "{s}:{}:{}", .{ if (self.label) |label| label else "(null)", self.currentLocation.line, self.currentLocation.character });
}

pub fn line(self: *const Stream, location: Location) []const u8 {
    var index = if (location.index >= self.data.len) self.data.len - 1 else location.index;
    while (index > 0 and self.data[index] != '\n') : (index -= 1) {}

    const start = index;
    const end = std.mem.indexOfScalarPos(u8, self.data, location.index, '\n') orelse self.data.len;
    return self.data[start..end];
}

test "remaining" {
    const s = Stream.init("stream", null);
    try std.testing.expect(s.remaining() == 6);
}

test "diff" {
    const s = Stream.init("stream", null);
    const s1 = s.eat(1);

    try std.testing.expectEqualSlices(u8, s.diff(s1), "s");
}
