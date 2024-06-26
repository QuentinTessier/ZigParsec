const std = @import("std");

pub const BaseState = struct {
    extensions: ?*anyopaque = null, // Can store things like SlitOperators for Expression Parser

    pub fn getParent(self: *BaseState, comptime T: type) *T {
        return @fieldParentPtr("baseState", self);
    }

    pub fn getExtension(self: *BaseState, comptime Ext: type) ?*Ext {
        return if (self.extensions) |ptr| @as(*Ext, @ptrCast(@alignCast(ptr))) else null;
    }
};

// Given a type S generates a new type to fit the BaseState.getParent()
pub fn MakeUserStateType(comptime S: type) type {
    const info = @typeInfo(S);
    switch (info) {
        .Struct => |s| {
            var fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};
            fields = fields ++ [_]std.builtin.Type.StructField{.{
                .name = "baseState",
                .type = BaseState,
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(BaseState),
            }};
            for (s.fields) |x| {
                fields = fields ++ [_]std.builtin.Type.StructField{x};
            }
            return @Type(.{ .Struct = .{
                .layout = .Auto,
                .is_tuple = false,
                .fields = fields,
                .decls = &[_]std.builtin.Type.Declaration{},
            } });
        },
        .Void => return BaseState,
        else => {
            var fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};
            fields = fields ++ [_]std.builtin.Type.StructField{.{
                .name = "baseState",
                .type = BaseState,
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(BaseState),
            }};
            fields = fields ++ [_]std.builtin.Type.StructField{.{
                .name = "userState",
                .type = S,
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(S),
            }};
            return @Type(.{ .Struct = .{
                .layout = .Auto,
                .is_tuple = false,
                .fields = fields,
                .decls = &[_]std.builtin.Type.Declaration{},
            } });
        },
    }
}

// The use of @fieldParentPtr is used to retrieve the actual userstate
