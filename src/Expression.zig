const std = @import("std");
const Stream = @import("Stream.zig");
const Result = @import("Result.zig").Result;
const Parser = @import("Parser.zig");
const Char = @import("Char.zig");
const Combinator = @import("Combinator.zig");
const runParser = Parser.runParser;
const ZigParsecState = @import("UserState.zig").ZigParsecState;

pub fn BuildExprParser(comptime ExprType: type, comptime TermParser: anytype) type {
    return struct {
        pub const ExprParserState = struct {
            operators: *const SplitOperator,
            extensions: ?*anyopaque = null,
        };

        pub const Assoc = enum(u32) {
            AssocNone,
            AssocLeft,
            AssocRight,
        };

        pub const PfnBinaryOperator = *const fn (std.mem.Allocator, ExprType, ExprType) anyerror!ExprType;
        pub const PfnUnaryOperator = *const fn (std.mem.Allocator, ExprType) anyerror!ExprType;
        pub const BinaryOperatorParser = *const fn (Stream, std.mem.Allocator, *ZigParsecState) anyerror!Result(PfnBinaryOperator);
        pub const UnaryOperatorParser = *const fn (Stream, std.mem.Allocator, *ZigParsecState) anyerror!Result(PfnUnaryOperator);

        pub const OperatorType = enum(u64) {
            Infix,
            Prefix,
            Postfix,
        };

        pub const Operator = union(OperatorType) {
            Infix: struct {
                fnc: BinaryOperatorParser,
                assoc: Assoc,
            },
            Prefix: UnaryOperatorParser,
            Postfix: UnaryOperatorParser,

            pub fn infix(fnc: BinaryOperatorParser, assoc: Assoc) Operator {
                return .{ .Infix = .{ .fnc = fnc, .assoc = assoc } };
            }

            pub fn prefix(fnc: UnaryOperatorParser) Operator {
                return .{ .Prefix = fnc };
            }

            pub fn postfix(fnc: UnaryOperatorParser) Operator {
                return .{ .Postfix = fnc };
            }
        };

        pub const SplitOperator = struct {
            rightAssoc: []BinaryOperatorParser,
            leftAssoc: []BinaryOperatorParser,
            noAssoc: []BinaryOperatorParser,
            prefix: []UnaryOperatorParser,
            postfix: []UnaryOperatorParser,

            pub fn deinit(self: SplitOperator, allocator: std.mem.Allocator) void {
                allocator.free(self.rightAssoc);
                allocator.free(self.leftAssoc);
                allocator.free(self.noAssoc);
                allocator.free(self.prefix);
                allocator.free(self.postfix);
            }

            pub fn createFromOperatorTable(allocator: std.mem.Allocator, table: []const []const Operator) !SplitOperator {
                var r = std.ArrayList(BinaryOperatorParser).init(allocator);
                var l = std.ArrayList(BinaryOperatorParser).init(allocator);
                var n = std.ArrayList(BinaryOperatorParser).init(allocator);
                var pre = std.ArrayList(UnaryOperatorParser).init(allocator);
                var post = std.ArrayList(UnaryOperatorParser).init(allocator);

                for (table) |row| {
                    for (row) |op| {
                        switch (op) {
                            .Prefix => |prefix_| try pre.append(prefix_),
                            .Postfix => |postfix_| try post.append(postfix_),
                            .Infix => |infix_| {
                                switch (infix_.assoc) {
                                    .AssocRight => try r.append(infix_.fnc),
                                    .AssocLeft => try l.append(infix_.fnc),
                                    .AssocNone => try n.append(infix_.fnc),
                                }
                            },
                        }
                    }
                }

                return .{
                    .rightAssoc = try r.toOwnedSlice(),
                    .leftAssoc = try l.toOwnedSlice(),
                    .noAssoc = try n.toOwnedSlice(),
                    .prefix = try pre.toOwnedSlice(),
                    .postfix = try post.toOwnedSlice(),
                };
            }
        };

        pub fn makeExprParserState(operators: *const SplitOperator) ExprParserState {
            return .{
                .operators = operators,
                .extensions = null,
            };
        }

        pub fn binary(comptime name: []const u8, comptime fnc: PfnBinaryOperator, comptime assoc: Assoc) Operator {
            return Operator.infix(
                struct {
                    pub fn apply(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(PfnBinaryOperator) {
                        return switch (try Char.string(stream, allocator, state, name)) {
                            .Result => |res| Result(PfnBinaryOperator).success(fnc, res.rest),
                            .Error => |err| Result(PfnBinaryOperator).failure(err.msg, err.rest),
                        };
                    }
                }.apply,
                assoc,
            );
        }

        pub fn prefix(comptime name: []const u8, comptime fnc: PfnUnaryOperator) Operator {
            return Operator.prefix(struct {
                pub fn apply(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(PfnUnaryOperator) {
                    return switch (try Char.string(stream, allocator, state, name)) {
                        .Result => |res| Result(PfnUnaryOperator).success(fnc, res.rest),
                        .Error => |err| Result(PfnUnaryOperator).failure(err.msg, err.rest),
                    };
                }
            }.apply);
        }

        pub fn postfix(comptime name: []const u8, comptime fnc: PfnUnaryOperator) Operator {
            return Operator.postfix(struct {
                pub fn apply(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(PfnUnaryOperator) {
                    return switch (try Char.string(stream, allocator, state, name)) {
                        .Result => |res| Result(PfnUnaryOperator).success(fnc, res.rest),
                        .Error => |err| Result(PfnUnaryOperator).failure(err.msg, err.rest),
                    };
                }
            }.apply);
        }

        pub fn id(_: std.mem.Allocator, x: ExprType) anyerror!ExprType {
            return x;
        }

        pub fn binOp(comptime assoc: Assoc) fn (stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(PfnBinaryOperator) {
            return struct {
                pub fn function(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(PfnBinaryOperator) {
                    const exprState: *ExprParserState = state.getExtension(ExprParserState) orelse unreachable;
                    const operators = switch (assoc) {
                        .AssocNone => exprState.operators.noAssoc,
                        .AssocRight => exprState.operators.rightAssoc,
                        .AssocLeft => exprState.operators.leftAssoc,
                    };
                    for (operators) |parser| {
                        switch (try parser(stream, allocator, state)) {
                            .Result => |res| return Result(PfnBinaryOperator).success(res.value, res.rest),
                            .Error => |err| {
                                err.msg.deinit();
                            },
                        }
                    }
                    return Result(PfnBinaryOperator).failure(std.ArrayList(u8).init(allocator), stream);
                }
            }.function;
        }

        pub fn ambigeous(comptime assoc: Assoc) fn (Stream, std.mem.Allocator, *ZigParsecState) anyerror!Result(ExprType) {
            return struct {
                pub fn function(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(ExprType) {
                    const exprState: *ExprParserState = state.getExtension(ExprParserState) orelse unreachable;
                    const operators = switch (assoc) {
                        .AssocNone => exprState.operators.noAssoc,
                        .AssocRight => exprState.operators.rightAssoc,
                        .AssocLeft => exprState.operators.leftAssoc,
                    };
                    const str = switch (assoc) {
                        .AssocNone => "none",
                        .AssocRight => "right",
                        .AssocLeft => "left",
                    };

                    for (operators) |parser| {
                        switch (try parser(stream, allocator, state)) {
                            .Result => {},
                            .Error => |err| {
                                err.msg.deinit();
                            },
                        }
                    }
                    var error_msg = std.ArrayList(u8).init(allocator);
                    var writer = error_msg.writer();
                    try writer.print("{}: ambiguous use of a {s} associative operator", .{ stream, str });
                    return Result(ExprType).failure(error_msg, stream);
                }
            }.function;
        }

        pub const ambigeousRight = ambigeous(.AssocRight);
        pub const ambigeousLeft = ambigeous(.AssocLeft);
        pub const ambigeousNone = ambigeous(.AssocNone);

        pub const rassocOp = binOp(.AssocRight);
        pub const lassocOp = binOp(.AssocLeft);
        pub const nassocOp = binOp(.AssocNone);

        pub fn prefixOp(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(PfnUnaryOperator) {
            const exprState: *ExprParserState = state.getExtension(ExprParserState) orelse return error.FailToGetOperatorTable;
            for (exprState.operators.prefix) |parser| {
                switch (try parser(stream, allocator, state)) {
                    .Result => |res| return Result(PfnUnaryOperator).success(res.value, res.rest),
                    .Error => |err| {
                        err.msg.deinit();
                    },
                }
            }
            //const prefixOperators = exprState.operators.prefix;
            //for (exprState.operators.prefix) |op| {}
            return Result(PfnUnaryOperator).success(id, stream);
        }

        pub fn postfixOp(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(PfnUnaryOperator) {
            const exprState: *ExprParserState = state.getExtension(ExprParserState) orelse unreachable;
            const postfixOperators = exprState.operators.postfix;
            for (postfixOperators) |parser| {
                switch (try parser(stream, allocator, state)) {
                    .Result => |res| return Result(PfnUnaryOperator).success(res.value, res.rest),
                    .Error => |err| {
                        err.msg.deinit();
                    },
                }
            }
            return Result(PfnUnaryOperator).success(id, stream);
        }

        pub fn termP(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(ExprType) {
            switch (try prefixOp(stream, allocator, state)) {
                .Result => |res_prefix| {
                    const prefix_fn = res_prefix.value;
                    switch (try runParser(res_prefix.rest, allocator, state, ExprType, TermParser)) {
                        .Result => |res_term| {
                            const x = res_term.value;
                            switch (try postfixOp(res_term.rest, allocator, state)) {
                                .Result => |res_postfix| {
                                    const postfix_fn = res_postfix.value;
                                    return Result(ExprType).success(try postfix_fn(allocator, try prefix_fn(allocator, x)), res_postfix.rest);
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

        pub fn rassocP1(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, x: ExprType) anyerror!Result(ExprType) {
            switch (try rassocP(stream, allocator, state, x)) {
                .Result => |res| return Result(ExprType).success(res.value, res.rest),
                .Error => |err| {
                    err.msg.deinit();
                    return Result(ExprType).success(x, stream);
                },
            }
        }

        pub fn rassocInnerFn(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, x: ExprType) anyerror!Result(ExprType) {
            switch (try rassocOp(stream, allocator, state)) {
                .Result => |res| {
                    const op_fn = res.value;
                    switch (try termP(res.rest, allocator, state)) {
                        .Result => |term| {
                            switch (try rassocP1(term.rest, allocator, state, term.value)) {
                                .Result => |p1_res| {
                                    return Result(ExprType).success(try op_fn(allocator, x, p1_res.value), p1_res.rest);
                                },
                                .Error => |err| return Result(ExprType).failure(err.msg, err.rest),
                            }
                        },
                        .Error => |err| return Result(ExprType).failure(err.msg, err.rest),
                    }
                },
                .Error => |err| return Result(ExprType).failure(err.msg, err.rest),
            }
        }

        pub fn rassocP(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, x: ExprType) anyerror!Result(ExprType) {
            return Parser.Combinator.choice(stream, allocator, state, ExprType, &.{
                .{ .parser = rassocInnerFn, .args = .{x} },
                ambigeousLeft,
                ambigeousNone,
            });
        }

        pub fn lassocInnerFn(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, x: ExprType) anyerror!Result(ExprType) {
            switch (try lassocOp(stream, allocator, state)) {
                .Result => |op_res| {
                    std.log.info("OpFnc: {*}", .{op_res.value});
                    switch (try termP(op_res.rest, allocator, state)) {
                        .Result => |term_res| {
                            return lassocP1(term_res.rest, allocator, state, try op_res.value(allocator, x, term_res.value));
                        },
                        .Error => |err| return Result(ExprType).failure(err.msg, err.rest),
                    }
                },
                .Error => |err| return Result(ExprType).failure(err.msg, err.rest),
            }
        }

        pub fn lassocP1(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, x: ExprType) anyerror!Result(ExprType) {
            return Parser.Combinator.choice(stream, allocator, state, ExprType, &.{
                .{ .parser = lassocP, .args = .{x} },
                .{ .parser = Parser.ret, .args = .{ ExprType, x } },
            });
        }

        pub fn lassocP(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState, x: ExprType) anyerror!Result(ExprType) {
            return Parser.Combinator.choice(stream, allocator, state, ExprType, &.{
                .{ .parser = lassocInnerFn, .args = .{x} },
                ambigeousRight,
                ambigeousNone,
            });
        }

        pub fn expression(stream: Stream, allocator: std.mem.Allocator, state: *ZigParsecState) anyerror!Result(ExprType) {
            switch (try termP(stream, allocator, state)) {
                .Result => |res| {
                    // const parsers = &.{ rassocP, lassocP };
                    // inline for (parsers) |parser| {
                    //     switch (try parser(res.rest, allocator, state, res.value)) {
                    //         .Result => |res_sub| return Result(ExprType).success(res_sub.value, res_sub.rest),
                    //         .Error => |err| {
                    //             err.msg.deinit();
                    //         },
                    //     }
                    // }
                    // return Result(ExprType).success(res.value, res.rest);
                    //std.log.info("Successfully parsed first value : {}", .{res.value});
                    //return lassocP(res.rest, allocator, state, res.value);
                    return Parser.Combinator.choice(res.rest, allocator, state, ExprType, &.{
                        .{ .parser = rassocP, .args = .{res.value} },
                        .{ .parser = lassocP, .args = .{res.value} },
                        .{ .parser = Parser.ret, .args = .{ ExprType, res.value } },
                    });
                },
                .Error => |err| return Result(ExprType).failure(err.msg, err.rest),
            }
        }
    };
}
