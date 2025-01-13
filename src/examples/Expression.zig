const std = @import("std");
const Parser = @import("../Parser.zig");

const Expr = Parser.Expr.ExpressionParserGenerator(*Expression);

const BinOpType = enum {
    Add,
    Sub,
    Mul,
    Div,
};

const BinOp = struct {
    t: BinOpType,
    lhs: *Expression,
    rhs: *Expression,
};

const UnOpType = enum {
    Neg,
};

const UnOp = struct {
    t: UnOpType,
    rhs: *Expression,
};

const Expression = union(enum) {
    Literal: u8, // Single digit
    BinaryOp: BinOp,
    UnaryOp: UnOp,
};

pub fn MakeBinaryOperatorBuilder(comptime op: BinOpType) fn (std.mem.Allocator, *Expression, *Expression) anyerror!*Expression {
    return struct {
        pub fn inlineBuilder(allocator: std.mem.Allocator, lhs: *Expression, rhs: *Expression) anyerror!*Expression {
            const n = try allocator.create(Expression);
            n.* = .{ .BinaryOp = .{
                .t = op,
                .lhs = lhs,
                .rhs = rhs,
            } };

            return n;
        }
    }.inlineBuilder;
}

pub fn MakeUnaryOperatorBuilder(comptime op: UnOpType) fn (std.mem.Allocator, *Expression, *Expression) anyerror!*Expression {
    return struct {
        pub fn inlineBuilder(allocator: std.mem.Allocator, rhs: *Expression) anyerror!*Expression {
            const n = try allocator.create(Expression);
            n.* = .{ .UnaryOp = .{
                .t = op,
                .rhs = rhs,
            } };

            return n;
        }
    }.inlineBuilder;
}

pub fn term(stream: Parser.Stream, allocator: std.mem.Allocator, state: Parser.State) anyerror!Parser.Result(*Expression) {
    return Parser.map(stream, allocator, state, u8, Parser.Char.digit, *Expression, struct {
        pub fn inlineMap(a: std.mem.Allocator, digit: u8) anyerror!*Expression {
            const n = try a.create(Expression);
            n.* = .{
                .Literal = digit,
            };
            return n;
        }
    }.inlineMap);
}

const ExprP = Parser.Expr.ExpressionParserGenerator(*Expression);

// You can directly call this function, it follows the standard way to define a Parser.
pub const expression = ExprP.buildExpressionParser(.{
    .infix = &.{
        ExprP.InfixOperator.new(.{ Parser.Language.operator, .{ "+", "+" } }, .{ .LeftAssoc = 60 }, MakeBinaryOperatorBuilder(.Add)),
        ExprP.InfixOperator.new(.{ Parser.Language.operator, .{ "-", "-" } }, .{ .LeftAssoc = 60 }, MakeBinaryOperatorBuilder(.Sub)),
        ExprP.InfixOperator.new(.{ Parser.Language.operator, .{ "*", "*" } }, .{ .LeftAssoc = 70 }, MakeBinaryOperatorBuilder(.Mul)),
        ExprP.InfixOperator.new(.{ Parser.Language.operator, .{ "/", "/" } }, .{ .LeftAssoc = 70 }, MakeBinaryOperatorBuilder(.Div)),
    },
    .prefix = &.{
        Expr.PrefixOperator.new(.{ Parser.Language.operator, .{ "-", "=" } }, MakeUnaryOperatorBuilder(.Neg)),
    },
    .postfix = &.{},
}, term);
