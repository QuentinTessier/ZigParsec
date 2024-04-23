const std = @import("std");
pub const ExampleMath = @import("examples/math.zig");

// TODO: Make UserState compatible with void
// ----- Current support is a bit weird, need to passe a "non constant pointer to a void value"
// ----- const void_value: void = void{};
// ----- Parser(void).Char.symbol(s, allocator, &void_value, 'a');
// TODO: Own impl of https://hackage.haskell.org/package/parsec-3.1.17.0/docs/Text-Parsec-Expr.html
// TODO: map = *const fn (Stream, Allocator, *State, PType, Parser(PType), TType, *cosnt fn (Allocator, PType) !TType) !Result(TType)
// ----- Useful to implement integer and float parser, eg: Parser.Char.digits().map(struct { pub fn map_fn(Allocator, []u8) { return std.fmt.parseInt()}});
// TODO: Basic Language parser (integer, float, keyword, identifier, ...)
// TODO: Tests
pub fn Parser(comptime UserState: type) type {
    return struct {
        pub const Stream = @import("Stream.zig");
        pub const Char = @import("Char.zig").Char(UserState);
        pub const Combinator = @import("Combinator.zig").Combinator(UserState);
        pub const Result = @import("Result.zig").Result;
        pub const ParseError = @import("Result.zig").ParseError;

        pub fn pure(stream: Stream, _: std.mem.Allocator, _: *UserState) anyerror!Result(void) {
            return Result(void).success(void{}, stream);
        }

        pub fn noop(stream: Stream, allocator: std.mem.Allocator, _: *UserState) anyerror!Result(void) {
            var error_msg: ParseError = ParseError.init(allocator);
            try error_msg.appendSlice("Encountered parser NOOP");
            return Result(void).failure(error_msg, stream);
        }

        pub inline fn runParser(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime T: type, p: anytype) anyerror!Result(T) {
            const ParserWrapperType: type = @TypeOf(p);
            return switch (@typeInfo(ParserWrapperType)) {
                .Struct => @call(.auto, p.parser, .{ stream, allocator, state } ++ p.args),
                .Fn => @call(.auto, p, .{ stream, allocator, state }),
                else => unreachable,
            };
        }

        pub inline fn label(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime Value: type, p: anytype, str: []const u8) anyerror!Result(Value) {
            const r = try runParser(stream, allocator, state, Value, p);
            switch (r) {
                .Result => return r,
                .Error => |err| {
                    var error_msg = std.ArrayList(u8).init(allocator);
                    var writer = error_msg.writer();
                    try writer.print("{}: {s}", .{ stream, str });
                    err.msg.deinit();
                    return Result([]Value).failure(error_msg, stream);
                },
            }
        }
    };
}
