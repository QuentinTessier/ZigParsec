const std = @import("std");

pub const Stream = @This();

pub const Checkpoint = enum(usize) {
    begin = 0,
    end = std.math.maxInt(usize),
    _,
};

allocator: std.mem.Allocator,
reader: ?*std.Io.Reader = null,
bytes: *std.array_list.Aligned(u8, null),
offset: usize = 0,

pub fn is_partial(self: *const Stream) bool {
    return self.reader != null;
}

pub fn fixed(allocator: std.mem.Allocator, bytes: *std.array_list.Aligned(u8, null)) Stream {
    return .{
        .allocator = allocator,
        .bytes = bytes,
    };
}

pub fn partial(allocator: std.mem.Allocator, reader: *std.Io.Reader, bytes: *std.array_list.Aligned(u8, null)) Stream {
    return .{
        .allocator = allocator,
        .reader = reader,
        .bytes = bytes,
    };
}

pub fn peek(self: *const Stream) std.Io.Reader.AppendExactError!u8 {
    if (self.offset < self.bytes.items.len) {
        return self.bytes.items[self.offset];
    }

    if (self.reader) |reader| {
        try reader.appendExact(self.allocator, self.bytes, 1);
        return self.bytes.items[self.offset];
    }
    return error.EndOfStream;
}

pub fn peek_slice(self: *const Stream, n: usize) std.Io.Reader.AppendExactError![]const u8 {
    const available = self.bytes.items.len -| self.offset;
    if (available >= n) {
        return self.bytes.items[self.offset .. self.offset + n];
    }

    if (self.reader) |reader| {
        const needed = n - available;
        try reader.appendExact(self.allocator, self.bytes, needed);
        return self.bytes.items[self.offset .. self.offset + n];
    }
    return self.bytes.items[self.offset .. self.offset + available];
}

pub fn consume(self: *const Stream, n: usize) Stream {
    return .{
        .reader = self.reader,
        .bytes = self.bytes,
        .offset = self.offset + n,
        .allocator = self.allocator,
    };
}

pub fn checkpoint(self: *const Stream) Checkpoint {
    return @enumFromInt(self.offset);
}

pub fn backtrack(self: *const Stream, c: Checkpoint) Stream {
    return .{
        .reader = self.reader,
        .bytes = self.bytes,
        .offset = switch (c) {
            .begin => 0,
            .end => self.bytes.items.len - 1,
            else => @intFromEnum(c),
        },
        .allocator = self.allocator,
    };
}
