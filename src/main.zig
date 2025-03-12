const std = @import("std");
const Stream = @import("./Stream.zig");
const ParserResult = @import("./Result.zig").EitherResultOrError;
const ParseError = @import("./error/ParseError.zig");

const revolution: u32 = 3;
var current_index: u64 = 0;

pub fn errorGenerate(allocator: std.mem.Allocator, seed: u32) !ParseError {
    const loc: ParseError.Location = .{
        .index = current_index,
    };

    var err: ParseError = .init(loc);
    var buffer: [256]u8 = undefined;
    const context = try std.fmt.bufPrint(&buffer, "context_{}", .{seed});
    try err.contextItems.append(allocator, try allocator.dupe(u8, context));

    const pattern = try std.fmt.bufPrint(&buffer, "pattern_{}", .{seed});
    try err.expectedItems.append(allocator, .{ .pattern = try allocator.dupe(u8, pattern) });
    if (@mod(seed, revolution) == 0) {
        current_index += 1;
    }

    return err;
}

pub fn symbol(stream: Stream, allocator: std.mem.Allocator, c: u8) anyerror!ParserResult(u8, ParseError) {
    var err: ParseError = .init(stream.currentLocation);
    if (stream.isEOF()) {
        try err.expectedToken(allocator, &[1]u8{c});
        return ParserResult(u8, ParseError).failure(err, stream);
    }

    const peeked = stream.peek(1);
    if (peeked[0] == c) {
        return ParserResult(u8, ParseError).success(c, stream.eat(1));
    }

    try err.expectedToken(allocator, &[1]u8{c});
    try err.withContext(allocator, "symbol");
    return ParserResult(u8, ParseError).failure(err, stream);
}

pub fn main() !void {
    var instance: std.heap.DebugAllocator(.{}) = .init;
    defer _ = instance.deinit();

    const allocator = instance.allocator();

    const stdout = std.io.getStdOut();

    const stream: Stream = .init("bbzjgzepgjzg\nofpzjgzogoz", "stdin");
    var r = try symbol(stream, allocator, 'a');
    switch (r) {
        .Result => |result| {
            std.log.info("{}", .{result.value});
        },
        .Error => |_| {
            try r.Error.msg.print(stream, stdout.writer().any(), false);
            r.Error.msg.deinit(allocator);
        },
    }
}
