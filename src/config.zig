const Self = @This();

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const zon = std.zon;
const log = std.log.scoped(.config);

const rule = @import("config/rule.zig");
pub const Pattern = @import("config/rule/pattern.zig");

pub const InputDeviceRule = rule.InputDeviceRule;
pub const LibinputDeviceRule = rule.LibinputDeviceRule;
pub const XkbKeyboardRule = rule.XkbKeyboardRule;


input_device_rules: ?[]const InputDeviceRule = null,
libinput_device_rules: ?[]const LibinputDeviceRule = null,
xkb_keyboard_rules: ?[]const XkbKeyboardRule = null,


pub fn load(allocator: mem.Allocator, path: []const u8) !Self {
    const file = fs.cwd().openFile(path, .{ .mode = .read_only }) catch |err| {
        log.warn("Failed to open `{s}`: {}", .{ path, err });
        return .{};
    };
    defer file.close();

    const stat = try file.stat();

    var buffer = try allocator.alloc(u8, stat.size+1);
    defer allocator.free(buffer);

    buffer[stat.size] = 0;

    var file_read_buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&file_read_buffer);
    const reader = &file_reader.interface;
    try reader.readSliceAll(buffer[0..stat.size]);

    return try zon.parse.fromSlice(
        Self,
        allocator,
        buffer[0..stat.size:0],
        null,
        .{ .ignore_unknown_fields = true },
    );
}


pub inline fn free(allocator: mem.Allocator, config: Self) void {
    zon.parse.free(allocator, config);
}
