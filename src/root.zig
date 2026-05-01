pub const Parser = @import("parser/parser.zig").Parser;
pub const ParserResult = @import("parser/parser.zig").ParserResult;
pub const Fatal = @import("parser/parser.zig").Fatal;
pub const Result = @import("parser/result.zig").Result;
pub const ErrorPayload = @import("parser/result.zig").ErrorPayload;
pub const Combinator = @import("parser/combinator.zig").Combinator;
pub const Expr = @import("expression/generator.zig");

pub const Utf8 = struct {
    pub const Parser = @import("utf8/parser.zig").Utf8Parser;
    pub const Error = @import("utf8/error.zig").ParseError;
    pub const Stream = @import("utf8/stream.zig");
    pub const Language = @import("utf8/language.zig");
    pub const Char = @import("utf8/char.zig");
    pub const Comb = Combinator(Stream, Error);
    pub fn Expression(comptime ExprT: type) type {
        return Expr.ExpressionParserGenerator(Stream, ExprT, Error);
    }
};
