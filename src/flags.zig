const build_options = @import("build_options");
const std = @import("std");
const Io = std.Io;
const mem = std.mem;
const fmt = std.fmt;
const meta = std.meta;
const process = std.process;

const clap = @import("clap");
const wayland = @import("wayland");
const river = wayland.client.river;

const kwim = @import("kwim");
const config = @import("config");


const parsers = .{
    .SUBCOMMANDS = clap.parsers.enumeration(@typeInfo(kwim.RunOption).@"union".tag_type.?),
    .DEVICE_TYPE = clap.parsers.enumeration(kwim.DeviceType),
    .DEVICE_NAME = clap.parsers.string,
    .REPEAT_INFO = clap.parsers.string,
    .SCROLL_FACTOR = clap.parsers.float(f64),
    .NUMLOCK_STATE = clap.parsers.enumeration(kwim.KeyboardNumlockState),
    .CAPSLOCK_STATE = clap.parsers.enumeration(kwim.KeyboardCapslockState),
    .KEYBOARD_LAYOUT = clap.parsers.string,
    .STRING = clap.parsers.string,
    .SEND_EVENT_MODE_STATE = clap.parsers.enumeration(river.LibinputDeviceV1.SendEventsModes.Enum),
    .TAP_STATE = clap.parsers.enumeration(river.LibinputDeviceV1.TapState),
    .DRAG_STATE = clap.parsers.enumeration(river.LibinputDeviceV1.DragState),
    .DRAG_LOCK_STATE = clap.parsers.enumeration(river.LibinputDeviceV1.DragLockState),
    .TAP_BUTTON_MAP = clap.parsers.enumeration(river.LibinputDeviceV1.TapButtonMap),
    .THREE_FINGER_DRAG_STATE = clap.parsers.enumeration(river.LibinputDeviceV1.ThreeFingerDragState),
    .CALIBRATION_MATRIX = clap.parsers.string,
    .ACCEL_PROFILE = clap.parsers.enumeration(river.LibinputDeviceV1.AccelProfile),
    .ACCEL_SPEED = clap.parsers.float(f64),
    .NATURAL_SCROLL_STATE = clap.parsers.enumeration(river.LibinputDeviceV1.NaturalScrollState),
    .LEFT_HANDED_STATE = clap.parsers.enumeration(river.LibinputDeviceV1.LeftHandedState),
    .CLICK_METHOD = clap.parsers.enumeration(river.LibinputDeviceV1.ClickMethod),
    .CLICKFINGER_BUTTON_MAP = clap.parsers.enumeration(river.LibinputDeviceV1.ClickfingerButtonMap),
    .MIDDLE_BUTTON_EMULATION_STATE = clap.parsers.enumeration(river.LibinputDeviceV1.MiddleEmulationState),
    .SCROLL_METHOD = clap.parsers.enumeration(river.LibinputDeviceV1.ScrollMethod),
    .SCROLL_BUTTON = clap.parsers.enumeration(kwim.Button),
    .SCROLL_BUTTON_LOCK_STATE = clap.parsers.enumeration(river.LibinputDeviceV1.ScrollButtonLockState),
    .DISABLE_WHILE_TYPING_STATE = clap.parsers.enumeration(river.LibinputDeviceV1.DwtState),
    .DISABLE_WHILE_TRACKPOINTING_STATE = clap.parsers.enumeration(river.LibinputDeviceV1.DwtpState),
    .ROTATION_ANGLE = clap.parsers.int(u32, 0),
};
const main_params = clap.parseParamsComptime(
    \\ -h, --help                   Print this help message and exit
    \\ -v, --version                Print the version and exit
    \\ -c, --config <STRING>        Specify the configuration file path
    \\ <SUBCOMMANDS>                e.g. list, apply
    \\
);
const subcommand_params = clap.parseParamsComptime(
    \\ -h, --help                       Print this help message and exit
    \\ -n, --name <DEVICE_NAME>         Input device name
    \\ --regex                          Enable regex
    \\ --match-null                     If to match null name
    \\
);


pub fn parse(
    ctx: struct {
        gpa: mem.Allocator,
        arena: mem.Allocator,
        io: Io,
    },
    args: process.Args
) !?kwim.RunOption {
    var it = args.iterate();
    _ = it.next();

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(
        clap.Help,
        &main_params,
        parsers,
        &it,
        .{
            .diagnostic = &diag,
            .allocator = ctx.gpa,
            .terminating_positional = 0,
        },
    ) catch |err| {
        try diag.reportToFile(ctx.io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.helpToFile(ctx.io, .stdout(), clap.Help, &main_params, .{});
        process.exit(0);
    }
    if (res.args.version != 0) {
        var stdout_buffer: [16]u8 = undefined;
        var stdout_writer = Io.File.stdout().writer(ctx.io, &stdout_buffer);
        const stdout = &stdout_writer.interface;
        try stdout.writeAll(build_options.version++"\n");
        try stdout.flush();
        process.exit(0);
    }

    return
        if (res.positionals[0]) |option|
            switch (option) {
                .list => .{ .list = try parse_list(.{ .gpa = ctx.gpa, .io = ctx.io }, &it) },
                .apply => .{ .apply = try parse_apply(.{ .gpa = ctx.gpa, .io = ctx.io }, &it) },
            }
        else if (res.args.config) |config_path|
            .{ .apply = try config.load(.{ .gpa = ctx.gpa, .arena = ctx.arena, .io = ctx.io }, config_path) }
        else null;
}


fn parse_list(
    ctx: struct {
        gpa: mem.Allocator,
        io: Io,
    },
    it: *process.Args.Iterator
) !kwim.ListOption {
    const params = comptime clap.parseParamsComptime(
        \\ -h, --help       Print this help message and exit
        \\ <DEVICE_TYPE>    Device type (e.g. input-device, libinput-device, xkb-keyboard)
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(
        clap.Help,
        &params,
        parsers,
        it,
        .{
            .allocator = ctx.gpa,
            .diagnostic = &diag,
            .terminating_positional = 0,
        },
    ) catch |err| {
        try diag.reportToFile(ctx.io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.helpToFile(ctx.io, .stdout(), clap.Help, &params, .{});
        process.exit(0);
    }

    return .{
        .device_type = res.positionals[0] orelse return error.MissingDeviceType,
        .pattern = try parse_list_pattern(.{ .gpa = ctx.gpa, .io = ctx.io }, it),
    };
}


fn parse_list_pattern(
    ctx: struct {
        gpa: mem.Allocator,
        io: Io,
    },
    it: *process.Args.Iterator
) !?config.Pattern {
    const params = subcommand_params;

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(
        clap.Help,
        &params,
        parsers,
        it,
        .{
            .allocator = ctx.gpa,
            .diagnostic = &diag,
            .terminating_positional = 0,
        },
    ) catch |err| {
        try diag.reportToFile(ctx.io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.helpToFile(ctx.io, .stdout(), clap.Help, &params, .{});
        process.exit(0);
    }

    var pattern: ?config.Pattern = null;
    errdefer if (pattern) |p| ctx.gpa.free(p.str);

    if (res.args.name) |name| {
        pattern = .{
            .str = try ctx.gpa.dupe(u8, name),
        };
    }
    if (pattern) |*p| {
        if (res.args.@"regex" != 0) {
            p.regex = true;
        }
        if (res.args.@"match-null" != 0) {
            p.match_null = true;
        }
    }

    return pattern;
}


fn parse_apply(
    ctx: struct {
        gpa: mem.Allocator,
        io: Io,
    },
    it: *process.Args.Iterator
) !config.Config {
    const params = comptime clap.parseParamsComptime(
        \\ -h, --help       Print this help message and exit
        \\ <DEVICE_TYPE>    Device type (e.g. input-device, libinput-device, xkb-keyboard)
        \\
    );

    var cfg = config.Config{};

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(
        clap.Help,
        &params,
        parsers,
        it,
        .{
            .allocator = ctx.gpa,
            .diagnostic = &diag,
            .terminating_positional = 0,
        },
    ) catch |err| {
        try diag.reportToFile(ctx.io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.helpToFile(ctx.io, .stdout(), clap.Help, &params, .{});
        process.exit(0);
    }

    if (res.positionals[0]) |device_type| {
        switch (device_type) {
            .@"input-device" => {
                const rule = try parse_input_device(.{ .gpa = ctx.gpa, .io = ctx.io }, it);
                if (all_null(rule)) return error.MissingInputDeviceRule;

                var rules = try ctx.gpa.alloc(config.InputDeviceRule, 1);
                errdefer ctx.gpa.free(rules);
                rules[0] = rule;
                cfg.input_device_rules = rules;
            },
            .@"libinput-device" => {
                const rule = try parse_libinput_device(.{ .gpa = ctx.gpa, .io = ctx.io }, it);
                if (all_null(rule)) return error.MissingLibinputDeviceRule;

                var rules = try ctx.gpa.alloc(config.LibinputDeviceRule, 1);
                errdefer ctx.gpa.free(rules);
                rules[0] = rule;
                cfg.libinput_device_rules = rules;
            },
            .@"xkb-keyboard" => {
                const rule = try parse_xkb_keyboard(.{ .gpa = ctx.gpa, .io = ctx.io }, it);
                if (all_null(rule)) return error.MissingXkbKeyboardRule;

                var rules = try ctx.gpa.alloc(config.XkbKeyboardRule, 1);
                errdefer ctx.gpa.free(rules);
                rules[0] = rule;
                cfg.xkb_keyboard_rules = rules;
            },
        }
    }

    return cfg;
}


fn parse_input_device(
    ctx: struct {
        gpa: mem.Allocator,
        io: Io,
    },
    it: *process.Args.Iterator
) !config.InputDeviceRule {
    const params = subcommand_params ++ comptime clap.parseParamsComptime(
        \\ --repeat-info <REPEAT_INFO>      Keyboard repeat info (e.g. 50,300)
        \\ --scroll-factor <SCROLL_FACTOR>  Pointer scroll factor
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(
        clap.Help,
        &params,
        parsers,
        it,
        .{
            .allocator = ctx.gpa,
            .diagnostic = &diag,
        },
    ) catch |err| {
        try diag.reportToFile(ctx.io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.helpToFile(ctx.io, .stdout(), clap.Help, &params, .{});
        process.exit(0);
    }

    var rule = config.InputDeviceRule{};
    errdefer if (rule.name) |name| ctx.gpa.free(name.str);

    if (res.args.name) |name| {
        rule.name = .{ .str = try ctx.gpa.dupe(u8, name) };
    }
    if (rule.name) |*name| {
        if (res.args.@"regex" != 0) {
            name.regex = true;
        }
        if (res.args.@"match-null" != 0) {
            name.match_null = true;
        }
    }

    if (res.args.@"repeat-info") |repeat_info| {
        var split = mem.splitAny(u8, repeat_info, ",");
        rule.repeat_info = .{
            .rate = try fmt.parseInt(i32, mem.trim(u8, split.next().?, " "), 0),
            .delay = try fmt.parseInt(i32, mem.trim(u8, split.next().?, " "), 0),
        };
    }
    if (res.args.@"scroll-factor") |scroll_factor| {
        rule.scroll_factor = scroll_factor;
    }

    return rule;
}


fn parse_libinput_device(
    ctx: struct {
        gpa: mem.Allocator,
        io: Io,
    },
    it: *process.Args.Iterator
) !config.LibinputDeviceRule {
    const params = subcommand_params ++ comptime clap.parseParamsComptime(
        \\ --send-event-modes <SEND_EVENT_MODE_STATE>       Set send events mode (enabled, disabled, disabled_on_external_mouse)
        \\ --tap <TAP_STATE>                                Set tap to click state (enabled, disabled)
        \\ --drag <DRAG_STATE>                              Set tap-and-drag state (enabled, disabled)
        \\ --drag-lock <DRAG_LOCK_STATE>                    Set tap-and-drag lock state (enabled, disabled)
        \\ --tap-button-map <TAP_BUTTON_MAP>                Set tap button map (left_right_middle, left_middle_right)
        \\ --three-finger-drag <THREE_FINGER_DRAG_STATE>    Set three finger drag state (enabled, disabled)
        \\ --calibration-matrix <CALIBRATION_MATRIX>        Set calibration matrix (format: "a,b,c,d,e,f")
        \\ --accel-profile <ACCEL_PROFILE>                  Set acceleration profile (flat, adaptive, custom)
        \\ --accel-speed <ACCEL_SPEED>                      Set acceleration speed (-1.0 to 1.0)
        \\ --natural-scroll <NATURAL_SCROLL_STATE>          Set natural scrolling state (enabled, disabled)
        \\ --left-handed <LEFT_HANDED_STATE>                Set left-handed mode (enabled, disabled)
        \\ --click-method <CLICK_METHOD>                    Set click method (none, button_areas, clickfinger)
        \\ --clickfinger-button-map <CLICKFINGER_BUTTON_MAP> Set clickfinger button map (left_right_middle, left_middle_right)
        \\ --middle-button-emulation <MIDDLE_BUTTON_EMULATION_STATE> Set middle button emulation (enabled, disabled)
        \\ --scroll-method <SCROLL_METHOD>                  Set scroll method (none, two_finger, edge, on_button_down, on_button_down_lock)
        \\ --scroll-button <SCROLL_BUTTON>                  Set scroll button (e.g., left, right, middle, side, extra, forward, back, task)
        \\ --scroll-button-lock <SCROLL_BUTTON_LOCK_STATE>  Set scroll button lock state (enabled, disabled)
        \\ --disable-while-typing <DISABLE_WHILE_TYPING_STATE> Set disable-while-typing state (enabled, disabled)
        \\ --disable-while-trackpointing <DISABLE_WHILE_TRACKPOINTING_STATE> Set disable-while-trackpointing state (enabled, disabled)
        \\ --rotation-angle <ROTATION_ANGLE>                Set rotation angle in degrees (0-360)
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(
        clap.Help,
        &params,
        parsers,
        it,
        .{
            .allocator = ctx.gpa,
            .diagnostic = &diag,
        },
    ) catch |err| {
        try diag.reportToFile(ctx.io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.helpToFile(ctx.io, .stdout(), clap.Help, &params, .{});
        process.exit(0);
    }

    var rule = config.LibinputDeviceRule{};
    errdefer if (rule.name) |name| ctx.gpa.free(name.str);

    if (res.args.name) |name| {
        rule.name = .{ .str = try ctx.gpa.dupe(u8, name) };
    }
    if (rule.name) |*name| {
        if (res.args.@"regex" != 0) {
            name.regex = true;
        }
        if (res.args.@"match-null" != 0) {
            name.match_null = true;
        }
    }

    if (res.args.@"send-event-modes") |send_events_modes| {
        rule.send_events_modes = send_events_modes;
    }
    if (res.args.tap) |tap| {
        rule.tap = tap;
    }
    if (res.args.drag) |drag| {
        rule.drag = drag;
    }
    if (res.args.@"drag-lock") |drag_lock| {
        rule.drag_lock = drag_lock;
    }
    if (res.args.@"tap-button-map") |tap_button_map| {
        rule.tap_button_map = tap_button_map;
    }
    if (res.args.@"three-finger-drag") |three_finger_drag| {
        rule.three_finger_drag = three_finger_drag;
    }
    if (res.args.@"calibration-matrix") |calibration_matrix| {
        rule.calibration_matrix = undefined;
        var split = mem.splitAny(u8, calibration_matrix, ",");
        for (&rule.calibration_matrix.?) |*v| {
            v.* = try fmt.parseFloat(
                f32,
                mem.trim(u8, split.next().?, " "),
            );
        }
    }
    if (res.args.@"accel-profile") |accel_profile| {
        rule.accel_profile = accel_profile;
    }
    if (res.args.@"accel-speed") |accel_speed| {
        rule.accel_speed = accel_speed;
    }
    if (res.args.@"natural-scroll") |natural_scroll| {
        rule.natural_scroll = natural_scroll;
    }
    if (res.args.@"left-handed") |left_handed| {
        rule.left_handed = left_handed;
    }
    if (res.args.@"click-method") |click_method| {
        rule.click_method = click_method;
    }
    if (res.args.@"clickfinger-button-map") |clickfinger_button_map| {
        rule.clickfinger_button_map = clickfinger_button_map;
    }
    if (res.args.@"middle-button-emulation") |middle_button_emulation| {
        rule.middle_button_emulation = middle_button_emulation;
    }
    if (res.args.@"scroll-method") |scroll_method| {
        rule.scroll_method = scroll_method;
    }
    if (res.args.@"scroll-button") |scroll_button| {
        rule.scroll_button = scroll_button;
    }
    if (res.args.@"scroll-button-lock") |scroll_button_lock| {
        rule.scroll_button_lock = scroll_button_lock;
    }
    if (res.args.@"disable-while-typing") |disable_while_typing| {
        rule.disable_while_typing = disable_while_typing;
    }
    if (res.args.@"disable-while-trackpointing") |disable_while_trackpointing| {
        rule.disable_while_trackpointing = disable_while_trackpointing;
    }
    if (res.args.@"rotation-angle") |rotation_angle| {
        rule.rotation_angle = rotation_angle;
    }

    return rule;
}


fn parse_xkb_keyboard(
    ctx: struct {
        gpa: mem.Allocator,
        io: Io,
    },
    it: *process.Args.Iterator
) !config.XkbKeyboardRule {
    const params = subcommand_params ++ comptime clap.parseParamsComptime(
        \\ --numlock <NUMLOCK_STATE>        Set numlock state (enabled, disabled)
        \\ --capslock <CAPSLOCK_STATE>      Set capslock state (enabled, disabled)
        \\ --layout <KEYBOARD_LAYOUT>       Keyboard layout name, index or name
        \\ --keymap-file <STRING>           Keymap file (e.g. <file-path>@<format>)
        \\ --keymap-rules <STRING>          Rules in keymap options
        \\ --keymap-model <STRING>          Model in keymap options
        \\ --keymap-layout <STRING>         Layout in keymap options
        \\ --keymap-variant <STRING>        Variant in keymap options
        \\ --keymap-options <STRING>        Options in keymap options
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(
        clap.Help,
        &params,
        parsers,
        it,
        .{
            .allocator = ctx.gpa,
            .diagnostic = &diag,
        },
    ) catch |err| {
        try diag.reportToFile(ctx.io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.helpToFile(ctx.io, .stdout(), clap.Help, &params, .{});
        process.exit(0);
    }

    var rule = config.XkbKeyboardRule{};
    errdefer {
        if (rule.name) |name| ctx.gpa.free(name.str);
        if (rule.layout) |layout| {
            switch (layout) {
                .index => {},
                .name => |name| ctx.gpa.free(name),
            }
        }
        if (rule.keymap) |keymap| {
            switch (keymap) {
                .file => |file| {
                    ctx.gpa.free(file.path);
                },
                .options => |map| {
                    inline for (@typeInfo(@TypeOf(map)).@"struct".field_names) |field_name| {
                        if (@field(map, field_name)) |ptr| ctx.gpa.free(ptr);
                    }
                }
            }
        }
    }

    if (res.args.name) |name| {
        rule.name = .{ .str = try ctx.gpa.dupe(u8, name) };
    }
    if (rule.name) |*name| {
        if (res.args.@"regex" != 0) {
            name.regex = true;
        }
        if (res.args.@"match-null" != 0) {
            name.match_null = true;
        }
    }

    if (res.args.numlock) |state| {
        rule.numlock = state;
    }

    if (res.args.capslock) |state| {
        rule.capslock = state;
    }

    if (res.args.layout) |layout| {
        rule.layout = blk: {
            const index = fmt.parseInt(u32, layout, 0) catch
                break :blk .{ .name = try ctx.gpa.dupeSentinel(u8, layout, 0) };
            break :blk .{ .index = index };
        };
    }

    if (res.args.@"keymap-file") |str| {
        var split = mem.splitAny(u8, str, "@");
        rule.keymap = .{
            .file = .{
                .path = try ctx.gpa.dupe(u8, split.next().?),
                .format = meta.stringToEnum(river.XkbConfigV1.KeymapFormat, split.next().?).?,
            },
        };
    }

    if (rule.keymap == null) {
        inline for (@typeInfo(@TypeOf(rule.keymap.?.options)).@"struct".field_names) |field_name| {
            if (rule.keymap == null) rule.keymap = .{ .options = .{} };
            if (@field(res.args, "keymap-" ++ field_name)) |str| {
                @field(rule.keymap.?.options, field_name) = try ctx.gpa.dupe(u8, str);
            }
        }
    }

    return rule;
}


fn all_null(object: anytype) bool {
    inline for (@typeInfo(@TypeOf(object)).@"struct".field_names) |field_name| {
        if (@field(object, field_name) != null) return false;
    }
    return true;
}
