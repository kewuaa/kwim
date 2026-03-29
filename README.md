# Description

A input manager separated from [kwm], based on [River].

# Dependencies

- wayland (libwayland-client)
- xkbcommon

# Build

Requires zig 0.15.x.

```zig
zig build -Doptimize=ReleaseSafe
```

- `--prefix`: specify the path to install files

# Usage

Directly run `kwim`, will search the same configuration file of [kwm] by default.
And you could use `-c` or `--config` to specify custom configuration file path.
Below is a configuration example:

```zon
.{
    // rule part
    //
    // a rule pattern has fields below:
    //      str: pattern string, required
    //      regex: bool, if enable regex
    //      match_null: bool, if match null
    //
    // only the first rule matched will be applied

    // input device rules
    // full scheme:
    //      name: rule pattern
    //
    //      repeat_info: .{ .rate = i32, .delay = i32 }
    //      scroll_factor: f64
    .input_device_rules = .{
        .{ .repeat_info = .{ .rate = 50, .delay = 300 } },
    },

    // libinput device rules
    // full scheme:
    //      name: rule pattern
    //
    //      send_events_modes:
    //          .enabled
    //          .disabled
    //          .disabled_on_external_mouse
    //      tap: .enabled or .disabled
    //      drag: .enabled or .disabled
    //      drag_lock: .enabled or .disabled
    //      tap_button_map: .lrm or .lmr
    //      three_finger_drag:
    //          .disabled
    //          .enabled_3fg
    //          .enabled_4fg
    //      calibration_matrix: [6]f32
    //      accel_profile:
    //          .none
    //          .flat
    //          .adaptive
    //          .custom
    //      accel_speed: f32
    //      natural_scroll: .enabled or .disabled
    //      left_handed: .enabled or .disabled
    //      click_method:
    //          .none
    //          .button_areas
    //          .clickfinger
    //      clickfinger_button_map: .lrm or .lmr
    //      middle_button_emulation: .enabled or .disabled
    //      scroll_method:
    //          .no_scroll
    //          .two_finger
    //          .edge
    //          .on_button_down
    //      scroll_button:
    //          .left
    //          .right
    //          .middle
    //      scroll_button_lock: .enabled or .disabled
    //      disable_while_typing: .enabled or .disabled
    //      disable_while_trackpointing: .enabled or .disabled
    //      rotation_angle: u32
    .libinput_device_rules = .{
        .{ .name = .{ .str = ".*[tT]ouchpad", .regex = true }, .tap = .enabled, .drag = .enabled, .natural_scroll = .enabled },
        .{ .tap = .enabled, .drag = .enabled }
    },

    // xkb_keyboard rules
    // full scheme:
    //      name: rule pattern
    //
    //      numlock: .enabled or .disabled
    //      capslock: .enabled or .disabled
    //      layout:
    //          layout index: .{ .index = u32 }
    //          or
    //          layout name: .{ .name = "layout name" }
    //      keymap:
    //          .{ .file = .{ .path = "keymap file path", .format = .text_v1 or .text_v2 } }
    //          or
    //          .{
    //              .options = .{
    //                  .rules = ?[]const u8,
    //                  .model = ?[]const u8,
    //                  .layout = ?[]const u8,
    //                  .variant = ?[]const u8,
    //                  .options = ?[]const u8,
    //              }
    //          }
    .xkb_keyboard_rules = .{
        //
    },
}
```

## subcommands

- `kwim list`: list device information, `kwim list -h` to see details.
- `kwim apply`: apply a single rule for device, `kwim apply -h` to see defails.

[kwm]: https://github.com/kewuaa/kwm.git
[river]: https://codeberg.org/river/river
