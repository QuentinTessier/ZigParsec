const std = @import("std");
const Stream = @import("../Stream.zig");
const Result = @import("../Result.zig").Result;
const Parser = @import("../Parser.zig");
const runParser = Parser.runParser;
const State = @import("../UserState.zig").State;
const OperatorTableGenerator = @import("Operator.zig").OperatorTableGenerator;

pub fn ExpressionParserGenerator(comptime ExprType: type) type {
    return struct {
        pub const InfixOperator = OperatorTableGenerator(ExprType).InfixOperator;
        pub const PrefixOperator = OperatorTableGenerator(ExprType).PrefixOperator;
        pub const PostfixOperator = OperatorTableGenerator(ExprType).PostfixOperator;
        pub const OperatorTable = OperatorTableGenerator(ExprType).OperatorTable;

        pub fn buildExpressionParser(comptime OpTable: OperatorTable, comptime TermP: anytype) *const fn (Stream, std.mem.Allocator, State) anyerror!Result(ExprType) {
            return struct {
                fn prattPrefixOp(stream: Stream, allocator: std.mem.Allocator, state: State) anyerror!Result(PrefixOperator) {
                    const operators = OpTable.prefix;
                    for (operators) |parser| {
                        switch (try parser(stream, allocator, state)) {
                            .Result => |res| return Result(PrefixOperator).success(res.value, res.rest),
                            .Error => |err| err.msg.deinit(allocator),
                        }
                    }
                    return Result(PrefixOperator).success(PrefixOperator.id(), stream);
                }

                fn prattPostfixOp(stream: Stream, allocator: std.mem.Allocator, state: State) anyerror!Result(PostfixOperator) {
                    const operators = OpTable.postfix;
                    for (operators) |opParser| {
                        switch (opParser(stream, allocator, state)) {
                            .Result => |res| return Result(PostfixOperator).success(res.value, res.rest),
                            .Error => |err| err.msg.deinit(allocator),
                        }
                    }
                    return Result(PostfixOperator).success(PostfixOperator.id(), stream);
                }

                fn prattInfixOp(stream: Stream, allocator: std.mem.Allocator, state: State) anyerror!Result(InfixOperator) {
                    const operators = OpTable.infix;
                    for (operators) |opParser| {
                        switch (try opParser(stream, allocator, state)) {
                            .Result => |res| return Result(InfixOperator).success(res.value, res.rest),
                            .Error => |err| err.msg.deinit(allocator),
                        }
                    }
                    return Result(InfixOperator).failure(Parser.ParseError.init(stream.currentLocation), stream);
                }

                fn prattTerm(stream: Stream, allocator: std.mem.Allocator, state: State, termP: anytype) anyerror!Result(ExprType) {
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

                fn prattLoop(stream: Stream, allocator: std.mem.Allocator, state: State, termP: anytype, precLimit: u32, left: ExprType) anyerror!Result(ExprType) {
                    switch (try prattInfixOp(stream, allocator, state)) {
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
                            err.msg.deinit(allocator);
                            return Result(ExprType).success(left, stream);
                        },
                    }
                }

                fn pratt(stream: Stream, allocator: std.mem.Allocator, state: State, termP: anytype, precLimit: u32) anyerror!Result(ExprType) {
                    switch (try prattTerm(stream, allocator, state, termP)) {
                        .Result => |res| {
                            return prattLoop(res.rest, allocator, state, termP, precLimit, res.value);
                        },
                        .Error => |err| return Result(ExprType).failure(err.msg, err.rest),
                    }
                }

                pub fn exprP(stream: Stream, allocator: std.mem.Allocator, state: State) anyerror!Result(ExprType) {
                    return pratt(stream, allocator, state, TermP, 0);
                }
            }.exprP;
        }
    };
}
