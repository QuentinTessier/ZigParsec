const std = @import("std");
const Result = @import("../parser/result.zig").Result;
const Error = @import("../parser/error.zig").Error;
const Parser = @import("../parser/parser.zig").Parser;

pub const Association = enum(u1) {
    left,
    right,
};

pub const Precedence = packed struct(u32) {
    assoc: Association,
    value: u31,

    pub fn association(self: Precedence) Association {
        return self.assoc;
    }

    pub fn get(self: Precedence) u32 {
        return @intCast(self.value);
    }

    pub fn get_final(self: Precedence) u32 {
        return switch (self.assoc) {
            .left => @intCast(self.value),
            .right => @intCast(self.value - 1),
        };
    }
};

pub fn OperatorTableGenerator(comptime S: type, comptime ExprT: type, comptime E: type) type {
    return struct {
        pub const OpTable = struct {
            infix: []const InfixOperatorP,
            prefix: []const PrefixOperatorP,
            postfix: []const PostfixOperatorP,
        };

        pub const InfixOperatorP = Parser(S, InfixOperator, E);
        pub const InfixOperatorB = *const fn (std.mem.Allocator, ExprT, ExprT) anyerror!ExprT;
        pub const InfixOperator = struct {
            symbol: []const u8,
            prec: Precedence,
            builder: InfixOperatorB,

            pub fn new(comptime P: anytype, comptime precedence: Precedence, comptime builder: InfixOperatorB) InfixOperatorP {
                return struct {
                    const R = Result(S, InfixOperator, E);
                    pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
                        const res = try P(stream, allocator);
                        return switch (res) {
                            .result => |r| R.success(InfixOperator{
                                .symbol = r.value,
                                .prec = precedence,
                                .builder = builder,
                            }, r.rest),
                            .@"error" => |e| R.failure(e.value, e.rest),
                        };
                    }
                }.inline_parser;
            }
        };

        pub const PrefixOperatorP = Parser(S, PrefixOperator, E);
        pub const PrefixOperatorB = *const fn (std.mem.Allocator, ExprT) anyerror!ExprT;
        pub const PrefixOperator = struct {
            symbol: []const u8,
            builder: PrefixOperatorB,

            pub fn id() PrefixOperator {
                return .{
                    .symbol = "id",
                    .builder = struct {
                        pub fn id(_: std.mem.Allocator, expr: ExprT) anyerror!ExprT {
                            return expr;
                        }
                    }.id,
                };
            }

            pub fn new(comptime P: anytype, comptime builder: PrefixOperatorB) PrefixOperatorP {
                return struct {
                    const R = Result(S, PrefixOperator, E);
                    pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
                        const res = try P(stream, allocator);
                        return switch (res) {
                            .result => |r| R.success(PrefixOperator{
                                .symbol = r.value,
                                .builder = builder,
                            }, r.rest),
                            .@"error" => |e| R.failure(e.value, e.rest),
                        };
                    }
                }.inline_parser;
            }
        };

        pub const PostfixOperatorP = Parser(S, PostfixOperator, E);
        pub const PostfixOperatorB = *const fn (std.mem.Allocator, ExprT) anyerror!ExprT;
        pub const PostfixOperator = struct {
            symbol: []const u8,
            builder: PostfixOperatorB,

            pub fn id() PostfixOperator {
                return .{
                    .symbol = "id",
                    .builder = struct {
                        pub fn id(_: std.mem.Allocator, expr: ExprT) anyerror!ExprT {
                            return expr;
                        }
                    }.id,
                };
            }

            pub fn new(comptime P: anytype, comptime builder: PostfixOperatorB) PostfixOperatorP {
                return struct {
                    const R = Result(S, PostfixOperator, E);
                    pub fn inline_parser(stream: S, allocator: std.mem.Allocator) anyerror!R {
                        const res = try P(stream, allocator);
                        return switch (res) {
                            .result => |r| R.success(PostfixOperator{
                                .symbol = r.value,
                                .builder = builder,
                            }, r.rest),
                            .@"error" => |e| R.failure(e.value, e.rest),
                        };
                    }
                }.inline_parser;
            }
        };
    };
}
