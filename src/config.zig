const Self = @This();

const std = @import("std");
const Io = std.Io;
const mem = std.mem;
const zon = std.zon;
const log = std.log.scoped(.config);

const rule = @import("config/rule.zig");
pub const Pattern = @import("config/rule/pattern.zig");

pub const InputDeviceRule = rule.InputDeviceRule;
pub const LibinputDeviceRule = rule.LibinputDeviceRule;
pub const XkbKeyboardRule = rule.XkbKeyboardRule;


pub const Config = struct {
    input_device_rules: ?[]const InputDeviceRule = null,
    libinput_device_rules: ?[]const LibinputDeviceRule = null,
    xkb_keyboard_rules: ?[]const XkbKeyboardRule = null,
};


pub fn load(ctx: struct {
    gpa: mem.Allocator,
    arena: mem.Allocator,
    io: Io,
}, path: []const u8) !Config {
    log.info("loading configuraton from `{s}`", .{ path });

    const file = Io.Dir.cwd().openFile(ctx.io, path, .{ .mode = .read_only }) catch |err| {
        log.warn("Failed to open `{s}`: {}", .{ path, err });
        return .{};
    };
    defer file.close(ctx.io);

    const size = try file.length(ctx.io);
    var buffer = try ctx.gpa.alloc(u8, size+1);
    defer ctx.gpa.free(buffer);

    buffer[size] = 0;

    var file_read_buffer: [1024]u8 = undefined;
    var file_reader = file.reader(ctx.io, &file_read_buffer);
    const reader = &file_reader.interface;
    try reader.readSliceAll(buffer[0..size]);

    var diagnostics: zon.parse.Diagnostics = undefined;
    return zon.parse.fromSlice(
        Config,
        .{
            .gpa = ctx.gpa,
            .arena = ctx.gpa,
            .diagnostics = &diagnostics,
            .source = buffer[0..size :0],
            .ignore_unknown_fields = true,
        },
    ) catch |err| {
        log.err("Failed to parse: {f}", .{diagnostics.fmt(path)});
        return err;
    };
}
