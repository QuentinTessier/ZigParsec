const std = @import("std");

pub fn ParseAtom(comptime Token: type) type {
    return union(enum) {
        unexpected_token: Token,
        expected_token: Token,
        unexpected_range: []const Token,
        expected_range: []const Token,
        unexpected_message: []const u8,
        expected_message: []const u8,
        end_of_input: void,
    };
}

pub fn ParseError(comptime Stream: type, comptime Checkpoint: type, comptime Token: type) type {
    const Atom = ParseAtom(Token);

    return struct {
        _unexpected: ?Atom = null,
        _expected: std.array_list.Aligned(Atom, null) = .empty,

        start: ?Checkpoint = null,
        end: ?Checkpoint = null,

        pub const empty: @This() = .{};

        pub fn unexpected(self: *@This(), tok: Atom) *@This() {
            std.debug.assert(tok == .unexpected_token or tok == .unexpected_range or tok == .unexpected_message);
            self._unexpected = tok;
            return self;
        }

        // Figure out how to handles Zig errors
        pub fn expected(self: *@This(), allocator: std.mem.Allocator, atom: Atom) *@This() {
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
}
