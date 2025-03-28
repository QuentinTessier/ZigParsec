const std = @import("std");
pub const Error = @import("error.zig").Error;
pub const Result = @import("result.zig").Result;
pub const Input = @import("input.zig").Input;

pub const CharInput = Input(u8, '\n');
pub const Prim = @import("char.zig");
pub const Combinator = @import("comb.zig");

pub fn ParserFn(comptime I: type, comptime T: type, comptime E: type) type {
    return fn (I, std.mem.Allocator) anyerror!Result(I, T, E);
}
