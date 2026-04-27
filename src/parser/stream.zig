const std = @import("std");

pub fn is_valid_stream(comptime S: type) void {
    if (!@hasDecl(S, "peek")) {
        std.debug.assert(false);
    }

    if (!@hasDecl(S, "peek_slice")) {
        std.debug.assert(false);
    }

    if (!@hasDecl(S, "consume")) {
        std.debug.assert(false);
    }

    if (!@hasDecl(S, "checkpoint")) {
        std.debug.assert(false);
    }

    if (!@hasDecl(S, "backtrack")) {
        std.debug.assert(false);
    }
}
