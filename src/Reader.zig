const std = @import("std");

pub const Stream = @This();

inner: *std.Io.Reader,
line: u32,
column: u32,

interface: std.Io.Reader,

const vtable: std.Io.Reader.VTable = .{
    .stream = stream,
};

pub fn init(inner: *std.Io.Reader, buf: []u8) Stream {
    return .{
        .inner = inner,
        .line = 0,
        .column = 0,
        .interface = .{
            .vtable = &vtable,
            .buffer = buf,
            .seek = 0,
            .end = 0,
        },
    };
}

fn from_reader(r: *std.Io.Reader) *Stream {
    return @alignCast(@fieldParentPtr("interface", r));
}

pub fn stream(
    r: *std.Io.Reader,
    w: *std.Io.Writer,
    limit: std.Io.Limit,
) std.Io.Reader.StreamError!usize {
    const self = from_reader(r);
    const n = try self.inner.stream(w, limit);

    const produced = r.buffer[r.seek..r.end];
    for (produced) |byte| {
        if (byte == '\n') {
            self.line += 1;
            self.column = 0;
        } else {
            self.column += 1;
        }
    }

    return n;
}
