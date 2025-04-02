const std = @import("std");

pub const ErrKind = enum {
    Satisfy,
    Char,
    String,
    AnyOf,
    NoneOf,
    Range,
    Many,
    Many1,
    Choice,
    SepBy,
    Between,
};

// Any error type should be built following this type definition
pub fn Error(comptime I: type) type {
    return struct {
        input: I,

        pub fn fromKind(input: I, _: ErrKind) @This() {
            return .{
                .input = input,
            };
        }
    };
}
