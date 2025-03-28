const std = @import("std");

pub fn Input(comptime T: type, comptime line_break: T) type {
    return struct {
        data: []const T,
        line: u32,
        character: u32,

        pub fn init(buffer: []const T) @This() {
            return @This(){
                .data = buffer,
                .line = 1,
                .character = 1,
            };
        }

        pub inline fn peek1(self: @This()) ?u8 {
            return if (self.data.len == 0) null else self.data[0];
        }

        pub inline fn peekN(self: @This(), n: u32) []const u8 {
            const size = @min(self.data.len, @as(usize, @intCast(n)));

            return self.data[0..size];
        }

        pub fn eat1(self: @This()) @This() {
            var copy = self;
            if (copy.data[0] == line_break) {
                copy.line += 1;
                copy.character = 1;
            } else {
                copy.character += 1;
            }

            copy.data = copy.data[1..];
            return copy;
        }

        pub fn eatN(self: @This(), n: usize) @This() {
            var copy = self;
            for (0..n) |i| {
                if (copy.data[i] == line_break) {
                    copy.line += 1;
                    copy.character = 1;
                } else {
                    copy.character += 1;
                }
            }
            copy.data = copy.data[n..];
            return copy;
        }

        pub fn eof(self: @This()) bool {
            return self.data.len == 0;
        }
    };
}
