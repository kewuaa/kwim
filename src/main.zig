const builtins = @import("builtin");
const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const posix = std.posix;
const process = std.process;

const clap = @import("clap");
const wayland = @import("wayland");
const wl = wayland.client.wl;
const river = wayland.client.river;

const kwim = @import("kwim");
const Config = @import("config");

const flags = @import("flags.zig");

const Globals = struct {
    rwm_input_manager: ?*river.InputManagerV1 = null,
    rwm_libinput_config: ?*river.LibinputConfigV1 = null,
    rwm_xkb_config: ?*river.XkbConfigV1 = null,
};


pub fn main() !void {
    var gpa = switch (comptime builtins.mode) {
        .Debug => std.heap.GeneralPurposeAllocator(.{}) {},
        else => void{},
    };
    defer switch (comptime builtins.mode) {
        .Debug => if (gpa.deinit() != .ok) @panic("memory leak"),
        else => {}
    };

    const allocator = switch (comptime builtins.mode) {
        .Debug => gpa.allocator(),
        else => std.heap.smp_allocator,
    };

    kwim.init_allocator(&allocator);

    const option = try flags.parse(allocator) orelse kwim.RunOption {
        .apply = blk: {
            var path_buffer: [256]u8 = undefined;
            const config_path = try (
                if (posix.getenv("XDG_CONFIG_HOME")) |config_home|
                    fmt.bufPrint(&path_buffer, "{s}/kwm/config.zon", .{ config_home })
                else if (posix.getenv("HOME")) |home|
                    fmt.bufPrint(&path_buffer, "{s}/.config/kwm/config.zon", .{ home })
                else return error.GetConfigHomeFailed
            );
            break :blk try Config.load(allocator, config_path);
        }
    };
    defer switch (option) {
        .list => |list_option| if (list_option.pattern) |p| allocator.free(p.str),
        .apply => |config| Config.free(allocator, config),
    };

    const display = try wl.Display.connect(null);
    defer display.disconnect();

    {
        const registry = display.getRegistry() catch return error.GetRegistryFailed;

        var globals: Globals = .{};
        registry.setListener(*Globals, registry_listener, &globals);

        if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

        const rwm_input_manager = globals.rwm_input_manager orelse return error.MissingRiverInputManager;
        const rwm_libinput_config = globals.rwm_libinput_config orelse return error.MissingRiverLibinputConfig;
        const rwm_xkb_config = globals.rwm_xkb_config orelse return error.MissingRiverXkbConfig;

        kwim.init(
            rwm_input_manager,
            rwm_libinput_config,
            rwm_xkb_config,
        );
    }
    defer kwim.deinit();

    try kwim.run(display, option);
}


fn registry_listener(registry: *wl.Registry, event: wl.Registry.Event, globals: *Globals) void {
    switch (event) {
        .global => |global| {
            if (mem.orderZ(u8, global.interface, river.InputManagerV1.interface.name) == .eq) {
                globals.rwm_input_manager = registry.bind(global.name, river.InputManagerV1, 1) catch return;
            } else if (mem.orderZ(u8, global.interface, river.LibinputConfigV1.interface.name) == .eq) {
                globals.rwm_libinput_config = registry.bind(global.name, river.LibinputConfigV1, 1) catch return;
            } else if (mem.orderZ(u8, global.interface, river.XkbConfigV1.interface.name) == .eq) {
                globals.rwm_xkb_config = registry.bind(global.name, river.XkbConfigV1, 1) catch return;
            }
        },
        .global_remove => {},
    }
}
