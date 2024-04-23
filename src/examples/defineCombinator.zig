const std = @import("std");
// Stream doesn't depend on Parser(UserState)
const Stream = @import("../Stream.zig");
const Result = @import("../Result.zig");

pub fn MyCombinator(comptime UserState: type) type {
    return struct {
        // Allows to run parser with the tuple syntax or function
        const runParser = @import("../Parser.zig").Parser(UserState).runParser;

        // The return type of a Parser has to be defined using a comptime known type has argument.
        // The usage of block to define a return type might lead to a function returning an "anytype" upon evaluation by the compiler which causes an error.
        // eg: pub fn parser(comptime T: type) anyerror!Result(blk: { break :blk *T; });
        pub fn myCombinator(stream: Stream, allocator: std.mem.Allocator, state: *UserState, comptime Value: type, p: anytype) anyerror!Result(Value) {
            // To make sure all parser syntax are accounted for use the runParser function to execute your comptime known parser:
            switch (try runParser(stream, allocator, state, Value, p)) {
                .Result => {},
                .Error => {},
            }
        }
    };
}
