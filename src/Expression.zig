const std = @import("std");
const Stream = @import("Stream.zig");
const Result = @import("Result.zig").Result;
const Parser = @import("Parser.zig");
const Char = @import("Char.zig");
const Combinator = @import("Combinator.zig");
const runParser = Parser.runParser;
const ZigParsecState = @import("UserState.zig").ZigParsecState;

pub fn BuildExpressionParser(comptime ExprType: type) type {
    return struct {
        pub const OperatorPrecedence = union(enum(u32)) {
            LeftAssoc: u32,
            RightAssoc: u32,

            pub fn format(self: OperatorPrecedence, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
                return std.fmt.format(writer, "{s}:{}", switch (self) {
                    .LeftAssoc => |l| .{ "LeftAssoc", l },
                    .RightAssoc => |r| .{ "LeftAssoc", r },
                });
            }

            pub fn eq(self: OperatorPrecedence, other: OperatorPrecedence) bool {
                if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;
                return switch (self) {
                    .LeftAssoc => |l| (other.LeftAssoc == l),
                    .RightAssoc => |r| (other.RightAssoc == r),
                };
            }

            pub fn getPrecedence(self: OperatorPrecedence) u32 {
                return switch (self) {
                    .LeftAssoc => |l| l,
                    .RightAssoc => |r| r,
                };
            }

            pub fn getFinalPrecedence(self: OperatorPrecedence) u32 {
                return switch (self) {
                    .LeftAssoc => |l| l,
                    .RightAssoc => |r| r - 1,
                };
            }
        };

        pub const Operators = struct {
            infixOp: []const InfixOperatorParser,

            pub fn createStateExtension(allocator: std.mem.Allocator, infixOp: []const InfixOperatorParser) !*Operators {
                const op = try allocator.create(Operators);
                op.* = .{
                    .infixOp = infixOp,
                };
                return op;
            }

            pub fn destroyStateExtension(allocator: std.mem.Allocator, state: *ZigParsecState) void {
                const ptr = state.getExtension(Operators).?;
                allocator.destroy(ptr);
            }
        };

        pub const InfixOperatorParser = *const fn (Stream, std.mem.Allocator, *ZigParsecState) anyerror!Result(InfixOperator);
        pub const InfixOperatorBuilder = *const fn (std.mem.Allocator, ExprType, ExprType) anyerror!ExprType;

        pub const InfixOperator = struct {
            symbol: []const u8,
            prec: OperatorPrecedence,
            builder: InfixOperatorBuilder,
        };

        pub fn makeInfixOperator(comptime symbol: []const u8, comptime precedence: OperatorPrecedence, comptime builder: InfixOperatorBuilder) InfixOperatorParser {
            return struct {
                pub fn inlineParser(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(InfixOperator) {
                    return switch (try Parser.Char.string(stream, allocator, state, symbol)) {
                        .Result => |res| Result(InfixOperator).success(InfixOperator{
                            .symbol = symbol,
                            .prec = precedence,
                            .builder = builder,
                        }, res.rest),
                        .Error => |err| Result(InfixOperator).failure(err.msg, err.rest),
                    };
                }
            }.inlineParser;
        }

        fn pratt(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, termP: anytype, precLimit: u32) anyerror!Result(ExprType) {
            switch (try runParser(stream, allocator, state, ExprType, termP)) {
                .Result => |res| {
                    const r = try prattLoop(res.rest, allocator, state, termP, precLimit, res.value);
                    //switch (r) {
                    //    .Result => |res1| {
                    //        //std.log.info("pratt(<{s}>, {}, ({}, <{s}>))", .{ stream.data[stream.currentLocation.index..], precLimit, res1.value, res1.rest.data[res1.rest.currentLocation.index..] });
                    //    },
                    //    else => {},
                    //}
                    return r;
                },
                .Error => |err| return Result(ExprType).failure(err.msg, err.rest),
            }
        }

        fn prattOp(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(InfixOperator) {
            const operators = state.getExtension(Operators) orelse unreachable;
            const infixOperators = operators.infixOp;

            for (infixOperators) |parser| {
                switch (try parser(stream, allocator, state)) {
                    .Result => |res| return Result(InfixOperator).success(res.value, res.rest),
                    .Error => |err| {
                        err.msg.deinit();
                    },
                }
            }
            return Result(InfixOperator).failure(std.ArrayList(u8).init(allocator), stream);
        }

        fn prattLoop(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, termP: anytype, precLimit: u32, left: ExprType) anyerror!Result(ExprType) {
            switch (try prattOp(stream, allocator, state)) {
                .Result => |res| {
                    const opPrec = res.value.prec.getPrecedence();
                    const finalPrec = res.value.prec.getFinalPrecedence();
                    if (opPrec > precLimit) {
                        switch (try pratt(res.rest, allocator, state, termP, finalPrec)) {
                            .Result => |res2| {
                                const right: ExprType = res2.value;
                                return prattLoop(
                                    res2.rest,
                                    allocator,
                                    state,
                                    termP,
                                    precLimit,
                                    try res.value.builder(allocator, left, right),
                                );
                            },
                            .Error => |err| return Result(ExprType).failure(err.msg, err.rest),
                        }
                    } else {
                        return Result(ExprType).success(left, stream);
                    }
                },
                .Error => |err| {
                    err.msg.deinit();
                    return Result(ExprType).success(left, stream);
                },
            }
        }

        pub fn expression(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, termP: anytype) anyerror!Result(ExprType) {
            return pratt(stream, allocator, state, termP, 0);
        }
    };
}
