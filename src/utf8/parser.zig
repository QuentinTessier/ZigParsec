const std = @import("std");

const Parser = @import("../parser/parser.zig").Parser;
const Stream = @import("stream.zig").Stream;
const ParseError = @import("error.zig").ParseError;

pub fn Utf8Parser(comptime V: type) type {
    return Parser(Stream, V, ParseError);
}
