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
For configuration details, could see [config.def.zon](https://github.com/kewuaa/kwm/blob/3860d2c0d7f772c030cf5b88c4d00d8d9b6c531a/config.def.zon#L1030).

## subcommands

- `kwim list`: list device information, `kwim list -h` to see details.
- `kwim apply`: apply a single rule for device, `kwim apply -h` to see defails.

[kwm]: https://github.com/kewuaa/kwm.git
[river]: https://codeberg.org/river/river
