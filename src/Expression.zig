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
            infixOp: []InfixOperatorParser,
            prefixOp: []PrefixOperatorParser,
            postfixOp: []PostfixOperatorParser,

            pub fn createStateExtension(allocator: std.mem.Allocator, infixOp: []const InfixOperatorParser, prefixOp: []const PrefixOperatorParser, postfixOp: []const PostfixOperatorParser) !*Operators {
                const op = try allocator.create(Operators);
                op.* = .{
                    .infixOp = try allocator.dupe(InfixOperatorParser, infixOp),
                    .prefixOp = try allocator.dupe(PrefixOperatorParser, prefixOp),
                    .postfixOp = try allocator.dupe(PostfixOperatorParser, postfixOp),
                };
                return op;
            }

            pub fn destroyStateExtension(allocator: std.mem.Allocator, state: *ZigParsecState) void {
                const ptr = state.getExtension(Operators).?;
                allocator.free(ptr.infixOp);
                allocator.free(ptr.prefixOp);
                allocator.free(ptr.postfixOp);
                allocator.destroy(ptr);
            }
        };

        pub const InfixOperatorParser = *const fn (Stream, std.mem.Allocator, *ZigParsecState) anyerror!Result(InfixOperator);
        pub const InfixOperatorBuilder = *const fn (std.mem.Allocator, ExprType, ExprType) anyerror!ExprType;
        pub const InfixOperator = struct {
            symbol: []const u8,
            prec: OperatorPrecedence,
            builder: InfixOperatorBuilder,

            pub fn new(comptime parser: anytype, comptime precedence: OperatorPrecedence, comptime builder: InfixOperatorBuilder) InfixOperatorParser {
                return struct {
                    pub fn inlineParser(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(InfixOperator) {
                        return switch (try runParser(stream, allocator, state, []const u8, parser)) {
                            .Result => |res| Result(InfixOperator).success(InfixOperator{
                                .symbol = res.value,
                                .prec = precedence,
                                .builder = builder,
                            }, res.rest),
                            .Error => |err| Result(InfixOperator).failure(err.msg, err.rest),
                        };
                    }
                }.inlineParser;
            }
        };

        pub const PrefixOperatorParser = *const fn (Stream, std.mem.Allocator, *ZigParsecState) anyerror!Result(PrefixOperator);
        pub const PrefixOperatorBuilder = *const fn (std.mem.Allocator, ExprType) anyerror!ExprType;
        pub const PrefixOperator = struct {
            symbol: []const u8,
            builder: PrefixOperatorBuilder,

            pub fn id() PrefixOperator {
                return .{
                    .symbol = "id_prefix",
                    .builder = struct {
                        pub fn id_fnc(_: std.mem.Allocator, expr: ExprType) anyerror!ExprType {
                            return expr;
                        }
                    }.id_fnc,
                };
            }

            pub fn new(comptime parser: anytype, comptime builder: PrefixOperatorBuilder) PrefixOperatorParser {
                return struct {
                    pub fn inlineParser(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(PrefixOperator) {
                        return switch (try runParser(stream, allocator, state, []const u8, parser)) {
                            .Result => |res| Result(PrefixOperator).success(PrefixOperator{
                                .symbol = res.value,
                                .builder = builder,
                            }, res.rest),
                            .Error => |err| Result(PrefixOperator).failure(err.msg, err.rest),
                        };
                    }
                }.inlineParser;
            }
        };

        pub const PostfixOperatorParser = *const fn (Stream, std.mem.Allocator, *ZigParsecState) anyerror!Result(PostfixOperator);
        pub const PostfixOperatorBuilder = *const fn (std.mem.Allocator, ExprType) anyerror!ExprType;
        pub const PostfixOperator = struct {
            symbol: []const u8,
            builder: PostfixOperatorBuilder,

            pub fn id() PostfixOperator {
                return .{
                    .symbol = "id_postfix",
                    .builder = struct {
                        pub fn id_fnc(_: std.mem.Allocator, expr: ExprType) anyerror!ExprType {
                            return expr;
                        }
                    }.id_fnc,
                };
            }

            pub fn new(comptime parser: anytype, comptime builder: PostfixOperatorBuilder) PostfixOperatorParser {
                return struct {
                    pub fn inlineParser(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(PrefixOperator) {
                        return switch (try runParser(stream, allocator, state, []const u8, parser)) {
                            .Result => |res| Result(PrefixOperator).success(PrefixOperator{
                                .symbol = res.value,
                                .builder = builder,
                            }, res.rest),
                            .Error => |err| Result(PrefixOperator).failure(err.msg, err.rest),
                        };
                    }
                }.inlineParser;
            }
        };

        fn pratt(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, termP: anytype, precLimit: u32) anyerror!Result(ExprType) {
            switch (try prattTerm(stream, allocator, state, termP)) {
                .Result => |res| {
                    return prattLoop(res.rest, allocator, state, termP, precLimit, res.value);
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

        fn prattPrefixOp(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(PrefixOperator) {
            const operators = state.getExtension(Operators) orelse unreachable;
            const prefixOperators = operators.prefixOp;

            for (prefixOperators) |parser| {
                switch (try parser(stream, allocator, state)) {
                    .Result => |res| return Result(PrefixOperator).success(res.value, res.rest),
                    .Error => |err| err.msg.deinit(),
                }
            }
            return Result(PrefixOperator).success(PrefixOperator.id(), stream);
        }

        fn prattPostfixOp(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(PostfixOperator) {
            const operators = state.getExtension(Operators) orelse unreachable;
            const postfixOperator = operators.postfixOp;

            for (postfixOperator) |parser| {
                switch (try parser(stream, allocator, state)) {
                    .Result => |res| return Result(PostfixOperator).success(res.value, res.rest),
                    .Error => |err| err.msg.deinit(),
                }
            }
            return Result(PostfixOperator).success(PostfixOperator.id(), stream);
        }

        fn prattTerm(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, termP: anytype) anyerror!Result(ExprType) {
            switch (try prattPrefixOp(stream, allocator, state)) {
                .Result => |res| {
                    const preFn = res.value.builder;
                    switch (try runParser(res.rest, allocator, state, ExprType, termP)) {
                        .Result => |res1| {
                            switch (try prattPostfixOp(stream, allocator, state)) {
                                .Result => |res2| {
                                    const postFn = res2.value.builder;
                                    return Result(ExprType).success(try postFn(allocator, try preFn(allocator, res1.value)), res1.rest);
                                },
                                .Error => unreachable,
                            }
                        },
                        .Error => |err| return Result(ExprType).failure(err.msg, err.rest),
                    }
                },
                .Error => unreachable,
            }
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
