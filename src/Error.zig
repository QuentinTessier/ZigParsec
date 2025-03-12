const std = @import("std");

pub const ExpectedItem = union(enum) {
    token: []u8,
    pattern: []u8,
    eof: void,
    custom: []u8,

    pub fn eql(self: *const ExpectedItem, other: *const ExpectedItem) bool {
        return switch (self.*) {
            .token => |tok| (std.meta.activeTag(other.*) == .token and std.mem.eql(u8, tok, other.*.token)),
            .pattern => |pat| (std.meta.activeTag(other.*) == .pattern and std.mem.eql(u8, pat, other.*.pattern)),
            .eof => (std.meta.activeTag(other.*) == .eof),
            .custom => |cust| (std.meta.activeTag(other.*) == .custom and std.mem.eql(u8, cust, other.*.custom)),
        };
    }

    pub fn deinit(self: *const ExpectedItem, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .token => |slice| allocator.free(slice),
            .pattern => |slice| allocator.free(slice),
            .custom => |slice| allocator.free(slice),
            .eof => {},
        }
    }

    pub fn dupe(self: *const ExpectedItem, allocator: std.mem.Allocator) !ExpectedItem {
        return switch (self.*) {
            .token => |tok| ExpectedItem{ .token = try allocator.dupe(u8, tok) },
            .pattern => |pat| ExpectedItem{ .pattern = try allocator.dupe(u8, pat) },
            .eof => ExpectedItem{ .eof = void{} },
            .custom => |cust| ExpectedItem{ .custom = try allocator.dupe(u8, cust) },
        };
    }
};

pub const ParseError2 = @This();

at: i32,
expected: std.ArrayListUnmanaged(ExpectedItem),
contexts: std.ArrayListUnmanaged([]u8),
custom_message: ?[]u8,
children: std.ArrayListUnmanaged(ParseError2),

pub fn init(loc: i32) ParseError2 {
    return .{
        .at = loc,
        .expected = .empty,
        .contexts = .empty,
        .custom_message = null,
        .children = .empty,
    };
}

pub fn shallow_deinit(self: *ParseError2, allocator: std.mem.Allocator) void {
    self.expected.deinit(allocator);
    self.contexts.deinit(allocator);
    self.children.deinit(allocator);
}

pub fn deinit(self: *ParseError2, allocator: std.mem.Allocator) void {
    for (self.expected.items) |expected| {
        expected.deinit(allocator);
    }
    self.expected.deinit(allocator);

    for (self.contexts.items) |c| {
        allocator.free(c);
    }
    self.contexts.deinit(allocator);

    if (self.custom_message) |c| {
        allocator.free(c);
    }

    for (self.children.items) |*child| {
        child.deinit(allocator);
    }
    self.children.deinit(allocator);
}

pub fn expect(self: *ParseError2, allocator: std.mem.Allocator, e: ExpectedItem) !void {
    return self.expected.append(allocator, e);
}

pub fn token(self: *ParseError2, allocator: std.mem.Allocator, tk: []const u8) !void {
    return self.expected.append(allocator, .{ .token = try allocator.dupe(u8, tk) });
}

pub fn pattern(self: *ParseError2, allocator: std.mem.Allocator, pt: []const u8) !void {
    return self.expected.append(allocator, .{ .pattern = try allocator.dupe(u8, pt) });
}

pub fn eof(self: *ParseError2, allocator: std.mem.Allocator) !void {
    return self.expected.append(allocator, .{ .eof = void{} });
}

pub fn custom(self: *ParseError2, allocator: std.mem.Allocator, ct: []const u8) !void {
    return self.expected.append(allocator, .{ .custom = try allocator.dupe(u8, ct) });
}

pub fn context(self: *ParseError2, allocator: std.mem.Allocator, c: []const u8) !void {
    return self.contexts.append(allocator, try allocator.dupe(u8, c));
}

pub fn message(self: *ParseError2, allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    self.custom_message = try std.fmt.allocPrint(allocator, fmt, args);
}

pub fn combine(self: *ParseError2, allocator: std.mem.Allocator, other: *ParseError2) !void {
    for (other.expected.items) |new| {
        for (self.expected.items) |contained| {
            if (new.eql(&contained)) {
                break;
            }
        } else {
            try self.expected.append(allocator, new.dupe(allocator));
        }
    }

    for (other.contexts.items) |new| {
        for (self.contexts.items) |contained| {
            if (std.mem.eql(u8, new, contained)) {
                break;
            }
        } else {
            try self.contexts.append(allocator, try allocator.dupe(u8, new));
        }
    }

    try self.children.append(allocator, other.*);
}

pub fn format(self: *const ParseError2, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    try writer.print("Parse error at {}:\n", .{self.at});
    try writer.print("While parsing ", .{});
    for (self.contexts.items, 0..) |c, i| {
        try writer.print("{s}{s}", .{ c, if (i < self.contexts.items.len - 1) " > " else "" });
    }
    try writer.print(":\nExpected: ", .{});
    for (self.expected.items, 0..) |e, i| {
        const str = switch (e) {
            .token => |tok| tok,
            .pattern => |pat| pat,
            .eof => "EOF",
            .custom => |cust| cust,
        };
        try writer.print("{s}{s}", .{ str, if (i < self.expected.items.len - 1) ", " else "" });
    }
    try writer.print("\n", .{});
    if (self.custom_message) |m| {
        try writer.print("{s}\n", .{m});
    }

    try writer.print("Caused by:\n");
    for (self.children) |child| {
        try writer.print("{}", .{child});
    }
    try writer.print("\n");
}

pub fn merge(errors: []ParseError2, allocator: std.mem.Allocator) !ParseError2 {
    const furstest = blk: {
        var max_distance: i32 = 0;
        var index: usize = 0;
        for (errors, 0..) |err, i| {
            if (max_distance < err.at) {
                index = i;
                max_distance = err.at;
            }
        }

        break :blk .{ max_distance, index };
    };

    var selected = errors[furstest[1]];

    for (errors, 0..) |*err, i| {
        if (err.at == furstest[0] and i != furstest[1]) {
            try selected.combine(allocator, err);
        }
    }

    return selected;
}
