const Self = @This();

const std = @import("std");
const log = std.log.scoped(.input_device_rule);

const kwim = @import("kwim");

const Pattern = @import("pattern.zig");

name: ?Pattern = null,

repeat_info: ?kwim.KeyboardRepeatInfo = null,
scroll_factor: ?f64 = null,


pub fn match(self: *const Self, name: ?[]const u8) bool {
    if (self.name) |pattern| {
        log.debug("try match name: `{s}` with {*}({*}: `{s}`)", .{ name orelse "null", self, &pattern, pattern.str });

        if (!pattern.is_match(name)) return false;
    }
    return true;
}
