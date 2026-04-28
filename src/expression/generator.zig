const std = @import("std");
const Result = @import("../parser/result.zig").Result;
const Error = @import("../parser/error.zig").Error;
const Parser = @import("../parser/parser.zig").Parser;
const operator = @import("operator.zig");

pub fn ExpressionParserGenerator(comptime S: type, comptime ExprT: type, comptime E: type) type {
    return struct {
        pub const OperatorTableGenerator = operator.OperatorTableGenerator(S, ExprT, E);

        pub const InfixOperator = OperatorTableGenerator.InfixOperator;
        pub const PrefixOperator = OperatorTableGenerator.PrefixOperator;
        pub const PostfixOperator = OperatorTableGenerator.PostfixOperator;
        pub const OperatorTable = OperatorTableGenerator.OpTable;

        pub fn build_expression_parser(comptime op_table: OperatorTable, comptime termP: Parser(S, ExprT, E)) Parser(S, ExprT, E) {
            return struct {
                const R = Result(S, ExprT, Error(E));
                const PrattPrefixResult = Result(S, PrefixOperator, Error(E));
                fn pratt_prefix_op(stream: S, allocator: std.mem.Allocator) anyerror!PrattPrefixResult {
                    const operators = op_table.prefix;
                    inline for (operators) |p| {
                        const res = try p(stream, allocator);
                        switch (res) {
                            .result => return res,
                            .@"error" => {},
                        }
                    }

                    return PrattPrefixResult.success(PrefixOperator.id(), stream);
                }

                const PrattPostfixResult = Result(S, PostfixOperator, Error(E));
                fn pratt_postfix_op(stream: S, allocator: std.mem.Allocator) anyerror!PrattPostfixResult {
                    const operators = op_table.postfix;
                    inline for (operators) |p| {
                        const res = try p(stream, allocator);
                        switch (res) {
                            .result => return res,
                            .@"error" => {},
                        }
                    }

                    return PrattPostfixResult.success(PostfixOperator.id(), stream);
                }

                const PrattInfixResult = Result(S, InfixOperator, Error(E));
                fn pratt_infix_op(stream: S, allocator: std.mem.Allocator) anyerror!PrattInfixResult {
                    const checkpoint = stream.checkpoint();
                    const operators = op_table.infix;
                    var last_err: ?E = null;
                    inline for (operators) |p| {
                        const res = try p(stream, allocator);
                        switch (res) {
                            .result => return res,
                            .@"error" => |e| switch (e.value) {
                                .fatal => return res,
                                .backtrack => |inner| {
                                    if (last_err != null) {
                                        _ = last_err.?.@"or"(allocator, &inner);
                                    } else {
                                        last_err = inner;
                                    }
                                },
                            },
                        }
                    }

                    _ = last_err.?.append(stream, checkpoint);
                    return PrattInfixResult.failure(.{ .backtrack = last_err.? }, stream);
                }

                fn pratt_term(stream: S, allocator: std.mem.Allocator) anyerror!R {
                    // const checkpoint = stream.checkpoint();
                    const prefix = try pratt_prefix_op(stream, allocator);
                    switch (prefix) {
                        .result => |r| {
                            const pre_fn = r.value.builder;
                            const term = try termP(r.rest, allocator);
                            switch (term) {
                                .result => |r1| {
                                    const postfix = try pratt_postfix_op(r1.rest, allocator);
                                    switch (postfix) {
                                        .result => |r2| {
                                            const post_fn = r2.value.builder;
                                            return R.success(try post_fn(allocator, try pre_fn(allocator, r1.value)), r2.rest);
                                        },
                                        .@"error" => unreachable,
                                    }
                                },
                                .@"error" => return term,
                            }
                        },
                        .@"error" => unreachable,
                    }
                }

                fn pratt_loop(stream: S, allocator: std.mem.Allocator, prec_limit: u32, left: ExprT) anyerror!R {
                    const infix_op = try pratt_infix_op(stream, allocator);
                    switch (infix_op) {
                        .result => |res| {
                            const prec = res.value.prec.get();
                            const final_prec = res.value.prec.get_final();

                            if (prec > prec_limit) {
                                const pratt_res = try pratt(res.rest, allocator, final_prec);
                                switch (pratt_res) {
                                    .result => |r| {
                                        const right = r.value;
                                        return pratt_loop(
                                            r.rest,
                                            allocator,
                                            prec_limit,
                                            try res.value.builder(allocator, left, right),
                                        );
                                    },
                                    .@"error" => return pratt_res,
                                }
                            } else return R.success(left, stream);
                        },
                        .@"error" => return R.success(left, stream),
                    }
                }

                fn pratt(stream: S, allocator: std.mem.Allocator, prec_limit: u32) anyerror!R {
                    const term = try pratt_term(stream, allocator);
                    return switch (term) {
                        .result => |res| blk: {
                            break :blk pratt_loop(res.rest, allocator, prec_limit, res.value);
                        },
                        .@"error" => term,
                    };
                }

                pub fn expression(stream: S, allocator: std.mem.Allocator) anyerror!R {
                    return pratt(stream, allocator, 0);
                }
            }.expression;
        }
    };
}
