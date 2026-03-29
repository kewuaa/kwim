const Self = @This();

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const log = std.log.scoped(.context);

const wayland = @import("wayland");
const wl = wayland.client.wl;
const river = wayland.client.river;

const Config = @import("config");

const InputDevice = @import("input_device.zig");
const LibinputDevice = @import("libinput_device.zig");
const XkbKeyboard = @import("xkb_keyboard.zig");


var ctx: ?Self = null;


rwm_input_manager: *river.InputManagerV1,
rwm_libinput_config: *river.LibinputConfigV1,
rwm_xkb_config: *river.XkbConfigV1,

input_devices: wl.list.Head(InputDevice, .link) = undefined,
libinput_devices: wl.list.Head(LibinputDevice, .link) = undefined,
xkb_keyboards: wl.list.Head(XkbKeyboard, .link) = undefined,


pub fn init(
    rwm_input_manager: *river.InputManagerV1,
    rwm_libinput_config: *river.LibinputConfigV1,
    rwm_xkb_config: *river.XkbConfigV1,
) void {
    // initialize once
    if (ctx != null) return;

    log.debug("init context", .{});

    ctx = .{
        .rwm_input_manager = rwm_input_manager,
        .rwm_libinput_config = rwm_libinput_config,
        .rwm_xkb_config = rwm_xkb_config,
    };

    ctx.?.input_devices.init();
    ctx.?.libinput_devices.init();
    ctx.?.xkb_keyboards.init();

    rwm_input_manager.setListener(*Self, rwm_input_manager_listener, &ctx.?);
    rwm_libinput_config.setListener(*Self, rwm_libinput_config_listener, &ctx.?);
    rwm_xkb_config.setListener(*Self, rwm_xkb_config_listener, &ctx.?);
}


pub fn deinit() void {
    std.debug.assert(ctx != null);

    log.debug("deinit context", .{});

    defer ctx = null;

    ctx.?.rwm_input_manager.destroy();
    ctx.?.rwm_libinput_config.destroy();
    ctx.?.rwm_xkb_config.destroy();

    {
        var it = ctx.?.input_devices.safeIterator(.forward);
        while (it.next()) |input_device| {
            input_device.destroy();
        }
        ctx.?.input_devices.init();
    }

    {
        var it = ctx.?.libinput_devices.safeIterator(.forward);
        while (it.next()) |libinput_device| {
            libinput_device.destroy();
        }
        ctx.?.libinput_devices.init();
    }

    {
        var it = ctx.?.xkb_keyboards.safeIterator(.forward);
        while (it.next()) |xkb_config| {
            xkb_config.destroy();
        }
        ctx.?.xkb_keyboards.init();
    }
}


pub inline fn get() *Self {
    std.debug.assert(ctx != null);

    return &ctx.?;
}


pub fn apply_config(self: *Self, config: *const Config) void {
    log.debug("apply config", .{});

    if (config.input_device_rules) |input_device_rules| {
        var it = self.input_devices.safeIterator(.forward);
        while (it.next()) |input_device| {
            input_device.apply_rules(input_device_rules);
        }
    }
    if (config.libinput_device_rules) |libinput_device_rules| {
        var it = self.libinput_devices.safeIterator(.forward);
        while (it.next()) |libinput_device| {
            libinput_device.apply_rules(libinput_device_rules);
        }
    }
    if (config.xkb_keyboard_rules) |xkb_keyboard_rules| {
        var it = self.xkb_keyboards.safeIterator(.forward);
        while (it.next()) |xkb_keyboard| {
            xkb_keyboard.apply_rules(xkb_keyboard_rules);
        }
    }
}


pub fn list_input_devices(self: *Self) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    {
        var it = self.input_devices.safeIterator(.forward);
        while (it.next()) |input_device| {
            try stdout.print(
                "name: {s}, type: {s}\n",
                .{ input_device.name orelse "unknown", @tagName(input_device.type) },
            );
        }
    }

    try stdout.flush();
}


pub fn list_libinput_devices(self: *Self) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    {
        var it = self.libinput_devices.safeIterator(.forward);
        while (it.next()) |libinput_device| {
            try stdout.writeAll("==============================================\n");
            try stdout.print(
                "name: {s}\n",
                .{
                    (if (libinput_device.input_device) |input_device| input_device.name else null)
                    orelse "unknown",
                }
            );

            try stdout.print(
                "send_events_support: (disabled: {}, disabled_on_external_mouse: {})\n",
                .{
                    libinput_device.send_events_support.disabled,
                    libinput_device.send_events_support.disabled_on_external_mouse,
                },
            );
            if (@as(u32, @bitCast(libinput_device.send_events_support)) != 0) {
                try stdout.print(
                    "send_events_current: {s}\n",
                    .{ @tagName(
                        @as(
                            river.LibinputDeviceV1.SendEventsModes.Enum,
                            @enumFromInt(
                                @as(
                                    u32,
                                    @bitCast(libinput_device.send_events_current)
                                )
                            )
                        )
                    ) },
                );
            }

            try stdout.print("tap_support: {}\n", .{ libinput_device.tap_support });
            if (libinput_device.tap_support != 0) {
                inline for ([_][]const u8 { "tap_current", "drag_current", "drag_lock_current", "tap_button_map_current" }) |name| {
                    try stdout.print(name++": {s}\n", .{ @tagName(@field(libinput_device, name)) });
                }
            }

            try stdout.print("three_finger_drag_support: {}\n", .{ libinput_device.three_finger_drag_support });
            if (libinput_device.three_finger_drag_support != 0) {
                try stdout.print("three_finger_drag_current: {s}\n", .{ @tagName(libinput_device.three_finger_drag_current) });
            }

            try stdout.print(
                "accel_profiles_support: (flat: {}, adaptive: {}, custom: {})\n",
                .{
                    libinput_device.accel_profiles_support.flat,
                    libinput_device.accel_profiles_support.adaptive,
                    libinput_device.accel_profiles_support.custom,
                },
            );
            if (@as(u32, @bitCast(libinput_device.accel_profiles_support)) != 0) {
                try stdout.print("accel_profile_current: {s}\n", .{ @tagName(libinput_device.accel_profile_current) });
                try stdout.print("accel_speed_current: {d:.4}\n", .{ libinput_device.accel_speed_current });
            }

            try stdout.print("calibration_matrix_support: {}\n", .{ libinput_device.calibration_matrix_support });
            if (libinput_device.calibration_matrix_support) {
                try stdout.print("calibration_matrix_current: [", .{});
                for (libinput_device.calibration_matrix_current, 0..) |val, i| {
                    try stdout.print("{d:.4}", .{ val });
                    if (i < libinput_device.calibration_matrix_current.len - 1) {
                        try stdout.print(", ", .{});
                    }
                }
                try stdout.print("]\n", .{});
            }

            try stdout.print("natural_scroll_support: {}\n", .{ libinput_device.natural_scroll_support });
            if (libinput_device.natural_scroll_support) {
                try stdout.print("natural_scroll_current: {s}\n", .{ @tagName(libinput_device.natural_scroll_current) });
            }

            try stdout.print("left_handed_support: {}\n", .{ libinput_device.left_handed_support });
            if (libinput_device.left_handed_support) {
                try stdout.print("left_handed_current: {s}\n", .{ @tagName(libinput_device.left_handed_current) });
            }

            try stdout.print(
                "click_method_support: (button_areas: {}, clickfinger: {})\n",
                .{
                    libinput_device.click_method_support.button_areas,
                    libinput_device.click_method_support.clickfinger,
                },
            );
            if (@as(u32, @bitCast(libinput_device.click_method_support)) != 0) {
                try stdout.print("click_method_current: {s}\n", .{ @tagName(libinput_device.click_method_current) });
                try stdout.print("clickfinger_button_map_current: {s}\n", .{ @tagName(libinput_device.clickfinger_button_map_current) });
            }

            try stdout.print("middle_emulation_support: {}\n", .{ libinput_device.middle_emulation_support });
            if (libinput_device.middle_emulation_support) {
                try stdout.print("middle_emulation_current: {s}\n", .{ @tagName(libinput_device.middle_emulation_current) });
            }

            try stdout.print(
                "scroll_method_support: (two_finger: {}, edge: {}, on_button_down: {})\n",
                .{
                    libinput_device.scroll_method_support.two_finger,
                    libinput_device.scroll_method_support.edge,
                    libinput_device.scroll_method_support.on_button_down,
                },
            );
            if (@as(u32, @bitCast(libinput_device.scroll_method_support)) != 0) {
                try stdout.print("scroll_method_current: {s}\n", .{ @tagName(libinput_device.scroll_method_current) });
                try stdout.print("scroll_button_current: {s}\n", .{ @tagName(libinput_device.scroll_button_current) });
                try stdout.print("scroll_button_lock_current: {s}\n", .{ @tagName(libinput_device.scroll_button_lock_current) });
            }

            try stdout.print("dwt_support: {}\n", .{ libinput_device.dwt_support });
            if (libinput_device.dwt_support) {
                try stdout.print("dwt_current: {s}\n", .{ @tagName(libinput_device.dwt_current) });
            }

            try stdout.print("dwtp_support: {}\n", .{ libinput_device.dwtp_support });
            if (libinput_device.dwtp_support) {
                try stdout.print("dwtp_current: {s}\n", .{ @tagName(libinput_device.dwtp_current) });
            }

            try stdout.print("rotation_support: {}\n", .{ libinput_device.rotation_support });
            if (libinput_device.rotation_support) {
                try stdout.print("rotation_current: {d}°\n", .{ libinput_device.rotation_current });
            }
            try stdout.writeAll("==============================================\n");
        }
    }

    try stdout.flush();
}


pub fn list_xkb_keyboards(self: *Self) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    {
        var it = self.xkb_keyboards.safeIterator(.forward);
        while (it.next()) |xkb_keyboard| {
            try stdout.writeAll("==============================================\n");
            try stdout.print(
                "name: {s}\n",
                .{
                    (if (xkb_keyboard.input_device) |input_device| input_device.name else null)
                    orelse "unknown",
                }
            );
            try stdout.print("numlock: {s}\n", .{ @tagName(xkb_keyboard.numlock) });
            try stdout.print("capslock: {s}\n", .{ @tagName(xkb_keyboard.capslock) });
            try stdout.print("layout: (index: {}, name: {s})\n", .{ xkb_keyboard.layout.index, xkb_keyboard.layout.name orelse "unknown" });
            if (xkb_keyboard.keymap) |keymap| {
                switch (keymap) {
                    .file => |file| try stdout.print("keymap file: (path: {s}, format: {s})\n", .{ file.path, @tagName(file.format) }),
                    .options => |map| try stdout.print(
                        "keymap options: (rules: {s}, model: {s}, layout: {s}, variant: {s}, options: {s})\n",
                        .{
                            map.rules orelse "null",
                            map.model orelse "null",
                            map.layout orelse "null",
                            map.variant orelse "null",
                            map.options orelse "null",
                        },
                    ),
                }
            }
            try stdout.writeAll("==============================================\n");
        }
    }

    try stdout.flush();
}


fn rwm_input_manager_listener(rwm_input_manager: *river.InputManagerV1, event: river.InputManagerV1.Event, context: *Self) void {
    std.debug.assert(rwm_input_manager == context.rwm_input_manager);

    switch (event) {
        .input_device => |data| {
            log.debug("new input_device {*}", .{ data.id });

            const input_device = InputDevice.create(data.id) catch |err| {
                log.err("create input device failed: {}", .{ err });
                return;
            };

            context.input_devices.append(input_device);
        },
        .finished => {
            log.debug("{*} finished", .{ rwm_input_manager });

            rwm_input_manager.destroy();
        }
    }
}


fn rwm_libinput_config_listener(rwm_libinput_config: *river.LibinputConfigV1, event: river.LibinputConfigV1.Event, context: *Self) void {
    std.debug.assert(rwm_libinput_config == context.rwm_libinput_config);

    switch (event) {
        .libinput_device => |data| {
            log.debug("new libinput_device {*}", .{ data.id });

            const libinput_device = LibinputDevice.create(data.id) catch |err| {
                log.err("create libinput device failed: {}", .{ err });
                return;
            };

            context.libinput_devices.append(libinput_device);
        },
        .finished => {
            log.debug("{*} finished", .{ rwm_libinput_config });

            rwm_libinput_config.destroy();
        }
    }
}


fn rwm_xkb_config_listener(rwm_xkb_config: *river.XkbConfigV1, event: river.XkbConfigV1.Event, context: *Self) void {
    std.debug.assert(rwm_xkb_config == context.rwm_xkb_config);

    switch (event) {
        .xkb_keyboard => |data| {
            const xkb_keyboard = XkbKeyboard.create(data.id) catch |err| {
                log.err("create xkb_keyboard failed: {}", .{ err });
                return;
            };

            context.xkb_keyboards.append(xkb_keyboard);
        },
        .finished => {
            log.debug("{*} finished", .{ rwm_xkb_config });

            rwm_xkb_config.destroy();
        }
    }
}
