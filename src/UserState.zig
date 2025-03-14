const std = @import("std");

pub const State = struct {
    should_collect_value: bool = true,
    should_collect_error: bool = true,
    auto_eat_whitespace: bool = false,

    verbose: bool = true,
};
