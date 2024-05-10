const std = @import("std");
const Parser = @import("../Parser.zig");

pub const LispState = struct {};

pub const Type = union(enum(u32)) {
    Nil: void, // nil
    Char: void, // 'a'
    String: void, // "abc"
    Integer32: void, // (as i32 1)
    UInteger32: void, // (as u32 1)
    Boolean: void, // true, false
    List: Type, // [i32]
    Tuple: []Type, // (i32, f32)
    Function: struct { // (Fn :: (i32, i32) -> i32)
        args: []Type,
        ret: Type,
    },
};

pub const Expression = union(enum(u32)) {
    AtomI32: i32,
    // AtomU32: u32,
    // AtomF32: f32,
    // AtomIdentifier: []u8,
    // AtomTypeDefinition: Type,
    //AtomBoolean: bool,
    AtomList: []Expression,
    AtomSymbol: []u8,
};

fn mapi32(allocator: std.mem.Allocator, str: []u8) anyerror!*Expression {
    const n = try allocator.create(Expression);
    n.* = .{
        .AtomI32 = try std.fmt.parseInt(i32, str, 10),
    };
    allocator.free(str);
    return n;
}

fn mapsymbol(allocator: std.mem.Allocator, str: []u8) anyerror!*Expression {
    const n = try allocator.create(Expression);
    n.* = .{
        .AtomSymbol = str,
    };
    return n;
}

pub fn atom_i32(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.BaseState) anyerror!Parser.Result(*Expression) {
    return Parser.map(stream, allocator, state, []u8, Parser.Language.integerString, *Expression, mapi32);
}

pub fn atom_symbol(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.BaseState) anyerror!Parser.Result(*Expression) {
    return Parser.map(stream, allocator, state, []u8, Parser.Language.identifier, *Expression, mapsymbol);
}

pub fn sexpr(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.BaseState) anyerror!Parser.Result(*Expression) {
    return Parser.Combinator.between(
        stream,
        allocator,
        state,
        .{ u8, *Expression, u8 },
        .{ Parser.Char.symbol, .{'('} },
        expr,
        .{ Parser.Char.symbol, .{')'} },
    );
}

pub fn expr(stream: Parser.Stream, allocator: std.mem.Allocator, state: *Parser.BaseState) anyerror!Parser.Result(*Expression) {
    return Parser.Combinator.choice(stream, allocator, state, *Expression, .{
        atom_i32,
        atom_symbol,
        sexpr,
    });
}
