const std = @import("std");

pub const State = struct {
    should_collect_value: bool = true,
    should_collect_error: bool = true,

    verbose: bool = true,
};
