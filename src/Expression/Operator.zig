const std = @import("std");
const Stream = @import("../Stream.zig");
const Result = @import("../Result.zig").Result;
const Parser = @import("../Parser.zig");
const runParser = Parser.runParser;
const State = @import("../UserState.zig").State;

// Allow for ordering of operators inside of the expression
pub const Precedence = union(enum(u32)) {
    LeftAssoc: u32,
    RightAssoc: u32,

    pub fn format(self: Precedence, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return std.fmt.format(writer, "{s}:{}", switch (self) {
            .LeftAssoc => |l| .{ "LeftAssoc", l },
            .RightAssoc => |r| .{ "LeftAssoc", r },
        });
    }

    pub fn eq(self: Precedence, other: Precedence) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;
        return switch (self) {
            .LeftAssoc => |l| (other.LeftAssoc == l),
            .RightAssoc => |r| (other.RightAssoc == r),
        };
    }

    pub fn getPrecedence(self: Precedence) u32 {
        return switch (self) {
            .LeftAssoc => |l| l,
            .RightAssoc => |r| r,
        };
    }

    pub fn getFinalPrecedence(self: Precedence) u32 {
        return switch (self) {
            .LeftAssoc => |l| l,
            .RightAssoc => |r| r - 1,
        };
    }
};

// Given the expression type, defines all the parser types needed to parse operators
pub fn OperatorTableGenerator(comptime ExprType: type) type {
    return struct {
        pub const OperatorTable = struct {
            infix: []const InfixOperatorParser,
            prefix: []const PrefixOperatorParser,
            postfix: []const PostfixOperatorParser,
        };

        pub const InfixOperatorParser = *const fn (Stream, std.mem.Allocator, State) anyerror!Result(InfixOperator);
        pub const InfixOperatorBuilder = *const fn (std.mem.Allocator, ExprType, ExprType) anyerror!ExprType;
        pub const InfixOperator = struct {
            symbol: []const u8,
            prec: Precedence,
            builder: InfixOperatorBuilder,

            pub fn new(parser: anytype, comptime precedence: Precedence, comptime builder: InfixOperatorBuilder) InfixOperatorParser {
                return struct {
                    pub fn inlineParser(stream: Stream, allocator: std.mem.Allocator, state: State) anyerror!Result(InfixOperator) {
                        return switch (try runParser(stream, allocator, state, []const u8, parser)) {
                            .Result => |res| Result(InfixOperator).success(InfixOperator{
                                .symbol = res.value,
                                .prec = precedence,
                                .builder = builder,
                            }, res.rest),
                            .Error => |err| blk: {
                                var local_error: Parser.ParseError = .init(err.rest.currentLocation);
                                try local_error.addChild(allocator, &err.msg);
                                break :blk Result(InfixOperator).failure(local_error, err.rest);
                            },
                        };
                    }
                }.inlineParser;
            }
        };

        pub const PrefixOperatorParser = *const fn (Stream, std.mem.Allocator, State) anyerror!Result(PrefixOperator);
        pub const PrefixOperatorBuilder = *const fn (std.mem.Allocator, ExprType) anyerror!ExprType;
        pub const PrefixOperator = struct {
            symbol: []const u8,
            builder: PrefixOperatorBuilder,

            pub fn id() PrefixOperator {
                return .{
                    .symbol = "id",
                    .builder = struct {
                        pub fn id_fnc(_: std.mem.Allocator, expr: ExprType) anyerror!ExprType {
                            return expr;
                        }
                    }.id_fnc,
                };
            }

            pub fn new(parser: anytype, comptime builder: PrefixOperatorBuilder) PrefixOperatorParser {
                return struct {
                    pub fn inlineParser(stream: Stream, allocator: std.mem.Allocator, state: State) anyerror!Result(PrefixOperator) {
                        return switch (try runParser(stream, allocator, state, []const u8, parser)) {
                            .Result => |res| Result(PrefixOperator).success(PrefixOperator{
                                .symbol = res.value,
                                .builder = builder,
                            }, res.rest),
                            .Error => |err| blk: {
                                var local_error: Parser.ParseError = .init(err.rest.currentLocation);
                                try local_error.addChild(allocator, &err.msg);
                                break :blk Result(PrefixOperator).failure(local_error, err.rest);
                            },
                        };
                    }
                }.inlineParser;
            }
        };

        pub const PostfixOperatorParser = *const fn (Stream, std.mem.Allocator, State) anyerror!Result(PostfixOperator);
        pub const PostfixOperatorBuilder = *const fn (std.mem.Allocator, ExprType) anyerror!ExprType;
        pub const PostfixOperator = struct {
            symbol: []const u8,
            builder: PostfixOperatorBuilder,

            pub fn id() PostfixOperator {
                return .{
                    .symbol = "id",
                    .builder = struct {
                        pub fn id_fnc(_: std.mem.Allocator, expr: ExprType) anyerror!ExprType {
                            return expr;
                        }
                    }.id_fnc,
                };
            }

            pub fn new(parser: anytype, comptime builder: PostfixOperatorBuilder) PostfixOperatorParser {
                return struct {
                    pub fn inlineParser(stream: Stream, allocator: std.mem.Allocator, state: State) anyerror!Result(PostfixOperator) {
                        return switch (try runParser(stream, allocator, state, []const u8, parser)) {
                            .Result => |res| Result(PostfixOperator).success(PostfixOperator{
                                .symbol = res.value,
                                .builder = builder,
                            }, res.rest),
                            .Error => |err| blk: {
                                var local_error: Parser.ParseError = .init(err.rest.currentLocation);
                                try local_error.addChild(allocator, &err.msg);
                                break :blk Result(PostfixOperator).failure(local_error, err.rest);
                            },
                        };
                    }
                }.inlineParser;
            }
        };
    };
}
