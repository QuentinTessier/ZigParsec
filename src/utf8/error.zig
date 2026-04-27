const std = @import("std");
const Stream = @import("stream.zig").Stream;
const Checkpoint = @import("stream.zig").Checkpoint;

pub const ErrorPrimitive = union(enum) {
    unexpected_token: u8,
    expected_token: u8,
    unexpected_range: []const u8,
    expected_range: []const u8,
    unexpected_message: []const u8,
    expected_message: []const u8,
    end_of_input: void,
};

pub const ParseError = struct {
    _unexpected: ?ErrorPrimitive = null,
    _expected: std.array_list.Aligned(ErrorPrimitive, null) = .empty,

    start: ?Checkpoint = null,
    end: ?Checkpoint = null,

    pub const empty: @This() = .{};

    pub fn unexpected(self: *@This(), prim: ErrorPrimitive) *@This() {
        std.debug.assert(prim == .unexpected_token or prim == .unexpected_range or prim == .unexpected_message);
        self._unexpected = prim;
        return self;
    }

    // Figure out how to handles Zig errors
    pub fn expected(self: *@This(), allocator: std.mem.Allocator, atom: ErrorPrimitive) *@This() {
        self._expected.append(allocator, atom) catch {};
        return self;
    }

    pub fn end_of_input(self: *@This()) *@This() {
        self._unexpected = .{ .end_of_input = void{} };
        return self;
    }

    pub fn @"or"(self: *@This(), allocator: std.mem.Allocator, other: *const @This()) *@This() {
        for (other._expected.items) |e| {
            self._expected.append(allocator, e) catch {};
        }
        return self;
    }

    pub fn append(self: *@This(), stream: Stream, start: Checkpoint) *@This() {
        if (self.start == null) {
            self.start = start;
        }

        if (self.end == null) {
            self.end = stream.checkpoint();
        }
        return self;
    }
};
