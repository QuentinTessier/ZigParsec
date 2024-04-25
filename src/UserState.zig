const std = @import("std");

pub const ZigParsecState = struct {
    extensions: ?*anyopaque = null, // Can store things like SlitOperators for Expression Parser

    pub fn getParent(self: *ZigParsecState, comptime T: type) *T {
        return @fieldParentPtr(T, "baseState", self);
    }

    pub fn getExtension(self: *ZigParsecState, comptime Ext: type) ?*Ext {
        return if (self.extensions) |ptr| @as(*Ext, @ptrCast(@alignCast(ptr))) else null;
    }
};

pub fn MakeUserStateType(comptime S: type) type {
    const info = @typeInfo(S);
    switch (info) {
        .Struct => |s| {
            var fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};
            fields = fields ++ [_]std.builtin.Type.StructField{.{
                .name = "baseState",
                .type = ZigParsecState,
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(ZigParsecState),
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
        .Void => return ZigParsecState,
        else => {
            var fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};
            fields = fields ++ [_]std.builtin.Type.StructField{.{
                .name = "baseState",
                .type = ZigParsecState,
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(ZigParsecState),
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
