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

    pub fn copy(self: *const ExpectedItem, allocator: std.mem.Allocator) !ExpectedItem {
        return switch (self.*) {
            .token => |tok| ExpectedItem{ .token = try allocator.dupe(u8, tok) },
            .pattern => |pat| ExpectedItem{ .pattern = try allocator.dupe(u8, pat) },
            .eof => ExpectedItem{ .eof = void{} },
            .custom => |cust| ExpectedItem{ .custom = try allocator.dupe(u8, cust) },
        };
    }
};
