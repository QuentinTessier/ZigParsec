const std = @import("std");
const ExpectedItem = @import("ExpectedItem.zig").ExpectedItem;
pub const Stream = @import("../Stream.zig").Stream;
pub const Location = @import("../Stream.zig").Location;

// TODO: Print style function for expected and context
// TODO: No copy function for expected, context and message if the user already allocated with the given allocator
pub const ParseError = @This();

loc: Location, // TODO: Make a span so the '~' part of the message has the right length
expectedItems: std.ArrayListUnmanaged(ExpectedItem),
contextItems: std.ArrayListUnmanaged([]u8),
customMessage: ?[]u8,
childErrors: std.ArrayListUnmanaged(ParseError),

pub fn init(loc: Location) ParseError {
    return .{
        .loc = loc,
        .expectedItems = .empty,
        .contextItems = .empty,
        .customMessage = null,
        .childErrors = .empty,
    };
}

pub fn deinit(self: *const ParseError, allocator: std.mem.Allocator) void {
    for (self.expectedItems.items) |item| {
        item.deinit(allocator);
    }
    // Hack: Since I don't want to pay the cost of having the allocator in all ArrayList
    // std.ArrayListUnmanaged(T).deinit(*@This()) takes a mutable to put the whole container to undefined (probably to catch use after deinit)
    // This function needs to accept a *const ParseError to make this easier when handling it in a switch
    allocator.free(self.expectedItems.allocatedSlice());

    for (self.contextItems.items) |item| {
        allocator.free(item);
    }
    allocator.free(self.contextItems.allocatedSlice());

    for (self.childErrors.items) |*item| {
        item.deinit(allocator);
    }
    allocator.free(self.childErrors.allocatedSlice());

    if (self.customMessage) |m| {
        allocator.free(m);
    }
}

pub fn copy(self: *const ParseError, allocator: std.mem.Allocator) !ParseError {
    var copyExpectedItems: std.ArrayListUnmanaged(ExpectedItem) = try .initCapacity(allocator, self.expectedItems.items.len);
    for (self.expectedItems.items) |item| {
        copyExpectedItems.appendAssumeCapacity(try item.copy(allocator));
    }

    var copyContextItems: std.ArrayListUnmanaged([]u8) = try .initCapacity(allocator, self.contextItems.items.len);
    for (self.contextItems.items) |item| {
        copyContextItems.appendAssumeCapacity(try allocator.dupe(u8, item));
    }

    const copyCustomMessage: ?[]u8 = if (self.customMessage) |m| try allocator.dupe(u8, m) else null;

    var copyChildErrors: std.ArrayListUnmanaged(ParseError) = try .initCapacity(allocator, self.childErrors.items.len);
    for (self.childErrors.items) |*item| {
        try copyChildErrors.append(allocator, try item.copy(allocator));
    }

    return .{
        .loc = self.loc,
        .expectedItems = copyExpectedItems,
        .contextItems = copyContextItems,
        .customMessage = copyCustomMessage,
        .childErrors = copyChildErrors,
    };
}

pub fn addChild(self: *ParseError, allocator: std.mem.Allocator, other: *const ParseError) !void {
    for (other.expectedItems.items) |new| {
        for (self.expectedItems.items) |contained| {
            if (new.eql(&contained)) break;
        } else {
            try self.expectedItems.append(allocator, try new.copy(allocator));
        }
    }

    for (other.contextItems.items) |new| {
        for (self.contextItems.items) |contained| {
            if (std.mem.eql(u8, new, contained)) break;
        } else {
            try self.contextItems.append(allocator, try allocator.dupe(u8, new));
        }
    }

    if (self.customMessage != null and other.customMessage != null) {
        const buffer = try std.fmt.allocPrint(allocator, "{s} | {s}", .{ self.customMessage.?, other.customMessage.? });
        allocator.free(self.customMessage.?);
        self.customMessage = buffer;
    } else if (self.customMessage == null and other.customMessage != null) {
        self.customMessage = try allocator.dupe(u8, other.customMessage.?);
    }

    try self.childErrors.append(allocator, other.*);
}

pub fn format(self: *const ParseError, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    try writer.print("Parse error at {}:\n", .{self.loc});
    try writer.print("While parsing ", .{});
    for (self.contextItems.items, 0..) |c, i| {
        try writer.print("{s}{s}", .{ c, if (i < self.contextItems.items.len - 1) " > " else "" });
    }
    try writer.print(":\nExpected: ", .{});
    for (self.expectedItems.items, 0..) |e, i| {
        const str = switch (e) {
            .token => |tok| tok,
            .pattern => |pat| pat,
            .eof => "EOF",
            .custom => |cust| cust,
        };
        try writer.print("{s}{s}", .{ str, if (i < self.expectedItems.items.len - 1) ", " else "" });
    }
    try writer.print("\n", .{});
    if (self.customMessage) |m| {
        try writer.print("{s}\n", .{m});
    }

    try writer.print("Caused by:\n", .{});
    for (self.childErrors.items) |child| {
        try writer.print("{}", .{child});
    }
    try writer.print("\n", .{});
}

pub fn findFurthest(errors: []const ParseError) usize {
    var max_distance: u64 = 0;
    var index: usize = 0;
    for (errors, 0..) |err, i| {
        if (max_distance < err.loc.index) {
            max_distance = err.loc.index;
            index = i;
        }
    }
    return index;
}

pub fn expectedToken(self: *@This(), allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    try self.expectedItems.append(allocator, .{
        .token = try std.fmt.allocPrint(allocator, fmt, args),
    });
}

pub fn expectedPattern(self: *@This(), allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    try self.expectedItems.append(allocator, .{
        .pattern = try std.fmt.allocPrint(allocator, fmt, args),
    });
}

pub fn expectedCustom(self: *@This(), allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    try self.expectedItems.append(allocator, .{
        .custom = try std.fmt.allocPrint(allocator, fmt, args),
    });
}

pub fn expectedEof(self: *@This(), allocator: std.mem.Allocator) !void {
    try self.expectedItems.append(allocator, .{
        .eof = void{},
    });
}

pub fn withContext(self: *@This(), allocator: std.mem.Allocator, context: []const u8) !void {
    try self.contextItems.append(allocator, try allocator.dupe(u8, context));
}

pub fn message(self: *@This(), allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    self.customMessage = try std.fmt.allocPrint(allocator, fmt, args);
}

pub fn print(self: *const @This(), stream: Stream, writer: std.io.AnyWriter, showContext: bool) !void {
    try writer.print("{?s}:{}:{}: error: ", .{ stream.label, self.loc.line, self.loc.character });
    if (self.customMessage) |m| {
        try writer.print("\n{s}\n", .{m});
    } else {
        try writer.writeByte('\n');
    }
    if (showContext and self.contextItems.items.len != 0) {
        _ = try writer.write("While parsing : ");
        for (self.contextItems.items, 0..) |item, i| {
            _ = try writer.write(item);
            if (i < self.contextItems.items.len - 1) {
                _ = try writer.write(" | ");
            }
        }
        try writer.writeByte('\n');
    }

    if (self.expectedItems.items.len == 0) {
        try writer.print("\tUnexpected\n\n", .{});
    } else {
        _ = try writer.write("Expected ");
        for (self.expectedItems.items, 0..) |item, i| {
            switch (item) {
                .custom => |str| try writer.print("{s}", .{str}),
                .token => |str| try writer.print("`{s}`", .{str}),
                .pattern => |str| try writer.print("\\{s}\\", .{str}),
                .eof => _ = try writer.write("EOF"),
            }
            if (i < self.expectedItems.items.len - 1) {
                _ = try writer.write(", ");
            }
        }
        try writer.writeByte('\n');
    }
    try writer.print("\t{s}\n", .{stream.line(self.loc)});
    try writer.print("\t", .{});
    for (0..self.loc.character - 1) |_| {
        try writer.writeByte(' ');
    }
    _ = try writer.write("^~~\n");
}

pub fn merge(allocator: std.mem.Allocator, errors: []ParseError) !ParseError {
    const index = findFurthest(errors);
    const selected = &errors[index];

    for (errors, 0..) |*err, i| {
        if (i != index and err.loc.index == selected.loc.index) {
            try selected.addChild(allocator, err);
        } else if (i != index) {
            err.deinit(allocator);
        }
    }

    return selected.*;
}
