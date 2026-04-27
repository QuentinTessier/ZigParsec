pub fn Error(comptime E: type) type {
    return union(enum) {
        backtrack: E,
        fatal: E,

        pub fn promote(self: @This()) @This() {
            return switch (self) {
                .backtrack => |e| .{ .fatal = e },
                .fatal => self,
            };
        }
    };
}
