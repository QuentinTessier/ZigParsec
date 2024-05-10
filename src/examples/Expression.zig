const std = @import("std");
const Parser = @import("../Parser.zig");
const Expression = Parser.Expression(*Expr);

pub const AST = enum {
    Lit,
    UnOp,
    BinOp,
};

pub const UnaryOperator = struct {
    pub const Kind = enum {
        Negate,
    };

    kind: Kind,
    rhs: *Expr,

    pub fn Generator(comptime k: Kind) fn (std.mem.Allocator, *Expr) anyerror!*Expr {
        return struct {
            pub fn gen(allocator: std.mem.Allocator, rhs: *Expr) anyerror!*Expr {
                const o = try allocator.create(Expr);
                o.* = .{ .UnOp = .{
                    .kind = k,
                    .rhs = rhs,
                } };
                return o;
            }
        }.gen;
    }
};

pub const BinaryOperator = struct {
    pub const Kind = enum {
        Add,
        Sub,
        Mul,
        Div,
    };

    kind: Kind,
    lhs: *Expr,
    rhs: *Expr,

    pub fn Generator(comptime k: Kind) fn (std.mem.Allocator, *Expr, *Expr) anyerror!*Expr {
        return struct {
            pub fn gen(allocator: std.mem.Allocator, lhs: *Expr, rhs: *Expr) anyerror!*Expr {
                const o = try allocator.create(Expr);
                o.* = .{ .BinOp = .{
                    .kind = k,
                    .lhs = lhs,
                    .rhs = rhs,
                } };
                return o;
            }
        }.gen;
    }
};

pub const Expr = union(AST) {
    Lit: i64,
    UnOp: UnaryOperator,
    BinOp: BinaryOperator,
};

pub const InfixOperators = [_]Expression.InfixOperatorParser{
    Expression.InfixOperator.new(.{ Parser.Language.operator, .{ "+", "+=" } }, .{ .LeftAssoc = 1 }, BinaryOperator.Generator(.Add)),
    Expression.InfixOperator.new(.{ Parser.Language.operator, .{ "-", "-=" } }, .{ .LeftAssoc = 1 }, BinaryOperator.Generator(.Sub)),
    Expression.InfixOperator.new(.{ Parser.Language.operator, .{ "*", null } }, .{ .LeftAssoc = 1 }, BinaryOperator.Generator(.Mul)),
    Expression.InfixOperator.new(.{ Parser.Language.operator, .{ "/", "/" } }, .{ .LeftAssoc = 1 }, BinaryOperator.Generator(.Div)),
};

pub const PrefixOperators = [_]Expression.PrefixOperatorParser{
    Expression.PrefixOperator.new(.{ Parser.Language.operator, .{ "-", "-=" }, UnaryOperator.Generator(.Negate) }),
};

fn mapFn(allocator: std.mem.Allocator, digits: []u8) anyerror!*Expr {
    const l = try allocator.create(*Expr);
    l.* = .{
        .Lit = try std.fmt.parseInt(i64, digits, 10),
    };
    allocator.free(digits);
    return l;
}

fn literal(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.BaseState) anyerror!Parser.Result(*Expr) {
    return Parser.Language.eatWhitespaceBefore(
        stream,
        allocator,
        state,
        *Expr,
        .{ Parser.map, .{ []u8, Parser.Language.integerString, *Expr, mapFn } },
    );
}

// Recursive definition to handle => '(' <expression> ')'
fn subexpression(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.BaseState) anyerror!Parser.Result(*Expr) {
    return Parser.Combinator.between(
        stream,
        allocator,
        state,
        .{ u8, *Expr, u8 },
        .{ Parser.Char.symbol, .{'('} },
        .{ Expression.expression, .{term} },
        .{ Parser.Char.symbol, .{')'} },
    );
}

fn term(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.BaseState) anyerror!Parser.Result(*Expr) {
    return Parser.Combinator.choice(stream, allocator, state, *Expr, .{
        subexpression,
        literal,
    });
}

pub fn makeStateExtension(allocator: std.mem.Allocator, state: *Parser.BaseState) !void {
    state.extensions = try Expression.Operators.createStateExtension(allocator, &InfixOperators, &.{});
}

pub fn destroyStateExtension(allocator: std.mem.Allocator, state: *Parser.BaseState) void {
    Expression.Operators.destroyStateExtension(allocator, state);
}
