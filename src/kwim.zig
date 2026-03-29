const std = @import("std");
const posix = std.posix;
const log = std.log.scoped(.kwim);

const wayland = @import("wayland");
const wl = wayland.client.wl;
const river = wayland.client.river;

const Config = @import("config");

const utils = @import("kwim/utils.zig");
const types = @import("kwim/types.zig");
const Context = @import("kwim/context.zig");
const InputDevice = @import("kwim/input_device.zig");
const XkbKeyboard = @import("kwim/xkb_keyboard.zig");

pub const Button = types.Button;
pub const KeyboardRepeatInfo = InputDevice.RepeatInfo;
pub const KeyboardNumlockState = XkbKeyboard.NumlockState;
pub const KeyboardCapslockState = XkbKeyboard.CapslockState;
pub const KeyboardLayout = XkbKeyboard.Layout;
pub const Keymap = XkbKeyboard.Keymap;

pub const init = Context.init;
pub const deinit = Context.deinit;
pub const init_allocator = utils.init_allocator;

pub const DeviceType = enum {
    @"input-device",
    @"libinput-device",
    @"xkb-keyboard",
};
pub const RunOption = union(enum) {
    apply: Config,
    list: DeviceType,
};


pub fn run(wl_display: *wl.Display, option: RunOption) !void {
    const context = Context.get();

    try dispatch_once(wl_display);

    switch (option) {
        .apply => |config| {
            log.debug("apply config: {any}", .{ config });
            context.apply_config(&config);
        },
        .list => |device_type| switch (device_type) {
            .@"input-device" => try context.list_input_devices(),
            .@"libinput-device" => try context.list_libinput_devices(),
            .@"xkb-keyboard" => try context.list_xkb_keyboards(),
        }
    }

    try dispatch_once(wl_display);
}


fn dispatch_once(wl_display: *wl.Display) !void {
    const wayland_fd = wl_display.getFd();

    var poll_fds = [_]posix.pollfd {
        .{ .fd = wayland_fd, .events = posix.POLL.IN, .revents = 0 },
    };

    if (wl_display.flush() != .SUCCESS) return error.FlushFaield;

    while (try posix.poll(&poll_fds, 100) > 0) {
        if (poll_fds[0].revents & posix.POLL.IN != 0) {
            if (wl_display.dispatch() != .SUCCESS) return error.DispatchFailed;
        }
    }
}
