const Self = @This();

const std = @import("std");
const Io = std.Io;
const mem = std.mem;
const meta = std.meta;
const heap = std.heap;
const posix = std.posix;
const linux = std.os.linux;
const log = std.log.scoped(.xkb_keyboard);

const xkbcommon = @import("xkbcommon");
const wayland = @import("wayland");
const wl = wayland.client.wl;
const river = wayland.client.river;

const config = @import("config");

const Context = @import("context.zig");
const InputDevice = @import("input_device.zig");

pub const NumlockState = enum {
    enabled,
    disabled,
};
pub const CapslockState = enum {
    enabled,
    disabled,
};
pub const Layout = union(enum) {
    index: u32,
    name: [:0]const u8,
};
pub const Keymap = union(enum) {
    file: struct {
        path: []const u8,
        format: river.XkbConfigV1.KeymapFormat,
    },
    options: struct {
        rules: ?[]const u8 = null,
        model: ?[]const u8 = null,
        layout: ?[]const u8 = null,
        variant: ?[]const u8 = null,
        options: ?[]const u8 = null,
    },
};

const ctx = Context.get();


link: wl.list.Link = undefined,

rwm_xkb_keyboard: *river.XkbKeyboardV1,

input_device: ?*InputDevice = null,

numlock: NumlockState = undefined,
capslock: CapslockState = undefined,
layout: struct {
    index: u32 = 0,
    name: ?[]const u8 = null,
} = .{},
keymap: ?Keymap = null,


pub fn create(rwm_xkb_keyboard: *river.XkbKeyboardV1) !*Self {
    const xkb_keyboard = try ctx.gpa.create(Self);
    errdefer ctx.gpa.destroy(xkb_keyboard);

    log.debug("<{*}> created", .{ xkb_keyboard });

    xkb_keyboard.* = .{
        .rwm_xkb_keyboard = rwm_xkb_keyboard,
    };
    xkb_keyboard.link.init();

    rwm_xkb_keyboard.setListener(*Self, rwm_xkb_keyboard_listener, xkb_keyboard);

    return xkb_keyboard;
}


pub fn destroy(self: *Self) void {
    log.debug("<{*}> destroyed", .{ self });

    if (self.layout.name) |name| {
        ctx.gpa.free(name);
        self.layout.name = null;
    }

    self.link.remove();
    self.rwm_xkb_keyboard.destroy();

    ctx.gpa.destroy(self);
}


pub fn apply_rules(self: *Self, rules: []const config.XkbKeyboardRule) void {
    log.debug("<{*}> apply rules", .{ self });

    for (rules) |rule| {
        if (rule.match((self.input_device orelse return).name)) {
            self.apply_rule(&rule);
            break;
        }
    }
}


fn apply_rule(self: *Self, rule: *const config.XkbKeyboardRule) void {
    if (rule.numlock) |state| {
        if (self.numlock != state) self.set_numlock(state);
    }

    if (rule.capslock) |state| {
        if (self.capslock != state) self.set_capslock(state);
    }

    var keymap_updated = false;
    if (rule.keymap) |keymap| blk: {
        self.set_keymap(&keymap) catch |err| {
            log.err("<{*}> set keymap failed: {}", .{ self, err });
            break :blk;
        };

        keymap_updated = true;

        if (self.layout.name) |name| ctx.gpa.free(name);
        self.layout = .{};
    }

    if (rule.layout) |layout| {
        if (keymap_updated or switch (layout) {
            .index => |index| index != self.layout.index,
            .name => |name| if (self.layout.name) |layout_name|
                !mem.eql(u8, layout_name, name) else true,
        }) self.set_layout(layout);
    }
}


fn set_numlock(self: *Self, state: NumlockState) void {
    log.info("<{*}> set numlock: {s}", .{ self, @tagName(state) });

    switch (state) {
        .enabled => self.rwm_xkb_keyboard.numlockEnable(),
        .disabled => self.rwm_xkb_keyboard.numlockDisable(),
    }
}


fn set_capslock(self: *Self, state: CapslockState) void {
    log.info("<{*}> set capslock: {s}", .{ self, @tagName(state) });

    switch (state) {
        .enabled => self.rwm_xkb_keyboard.capslockEnable(),
        .disabled => self.rwm_xkb_keyboard.capslockDisable(),
    }
}


fn set_layout(self: *Self, layout: Layout) void {
    switch (layout) {
        .index => |index| {
            log.info("<{*}> set keyboard layout to {}", .{ self, index });

            self.rwm_xkb_keyboard.setLayoutByIndex(@intCast(index));
        },
        .name => |name| {
            log.info("<{*}> set keyboard layout to {s}", .{ self, name });

            self.rwm_xkb_keyboard.setLayoutByName(name);
        }
    }
}


fn set_keymap(self: *Self, keymap: *const Keymap) !void {
    const rwm_xkb_keymap = switch (keymap.*) {
        .file => |file| blk: {
            log.info("<{*}> set keymap file: `{s}` with format {s}", .{ self, file.path, @tagName(file.format) });

            const f = try Io.Dir.cwd().openFile(ctx.io, file.path, .{ .mode = .read_write });
            defer f.close(ctx.io);

            break :blk try ctx.rwm_xkb_config.createKeymap(f.handle, file.format);
        },
        .options => |map| blk: {
            log.info(
                "<{*}> set keymap options: (rules: {s}, model: {s}, layout: {s}, variant: {s}, options: {s})",
                .{
                    self,
                    map.rules orelse "null",
                    map.model orelse "null",
                    map.layout orelse "null",
                    map.variant orelse "null",
                    map.options orelse "null",
                },
            );

            const xkb_context = xkbcommon.Context.new(.no_flags) orelse return error.XkbContextNewFailed;
            defer xkb_context.unref();

            var arena_allocator: heap.ArenaAllocator = .init(ctx.gpa);
            defer arena_allocator.deinit();
            const arena = arena_allocator.allocator();

            const xkb_keymap_rules = if (map.rules) |rules| try arena.dupeSentinel(u8, rules, 0) else null;
            const xkb_keymap_model = if (map.model) |model| try arena.dupeSentinel(u8, model, 0) else null;
            const xkb_keymap_layout = if (map.layout) |layout| try arena.dupeSentinel(u8, layout, 0) else null;
            const xkb_keymap_variant = if (map.variant) |variant| try arena.dupeSentinel(u8, variant, 0) else null;
            const xkb_keymap_options = if (map.options) |options| try arena.dupeSentinel(u8, options, 0) else null;

            const xkb_rule_names = xkbcommon.RuleNames {
                .rules = if (xkb_keymap_rules) |rules| rules.ptr else null,
                .model = if (xkb_keymap_model) |model| model.ptr else null,
                .layout = if (xkb_keymap_layout) |layout| layout.ptr else null,
                .variant = if (xkb_keymap_variant) |variant| variant.ptr else null,
                .options = if (xkb_keymap_options) |options| options.ptr else null,
            };

            const xkb_keymap = xkbcommon.Keymap.newFromNames(
                xkb_context,
                &xkb_rule_names,
                .no_flags,
            ) orelse return error.XkbKeymapNewFailed;
            defer xkb_keymap.unref();

            const fd = try posix.memfd_create("kwm-keymap-file", linux.MFD.CLOEXEC);
            defer posix_close(fd);

            const xkb_keymap_str = xkb_keymap.getAsString2(.text_v2, .{});
            _ = try posix_write(fd, mem.span(xkb_keymap_str orelse return error.GetXkbKeymapStringFailed));

            break :blk try ctx.rwm_xkb_config.createKeymap(fd, .text_v2);
        }
    };
    defer rwm_xkb_keymap.destroy();

    self.keymap = keymap.*;
    self.rwm_xkb_keyboard.setKeymap(rwm_xkb_keymap);
}


fn rwm_xkb_keyboard_listener(rwm_xkb_keyboard: *river.XkbKeyboardV1, event: river.XkbKeyboardV1.Event, xkb_keyboard: *Self) void {
    std.debug.assert(rwm_xkb_keyboard == xkb_keyboard.rwm_xkb_keyboard);

    switch (event) {
        .input_device => |data| {
            log.debug("<{*}> input_device: {*}", .{ xkb_keyboard, data.device });

            const rwm_input_device = data.device orelse return;
            const input_device: *InputDevice = @ptrCast(@alignCast(rwm_input_device.getUserData()));

            log.debug("<{*}> input_device, name: {s}", .{ xkb_keyboard, input_device.name orelse "" });

            xkb_keyboard.input_device = input_device;
        },
        .layout => |data| {
            log.debug("<{*}> layout, index: {}, name: {s}", .{ xkb_keyboard, data.index, data.name orelse "" });

            if (xkb_keyboard.layout.name) |name| {
                ctx.gpa.free(name);
                xkb_keyboard.layout.name = null;
            }

            xkb_keyboard.layout.index = data.index;
            if (data.name) |name| {
                xkb_keyboard.layout.name = ctx.gpa.dupe(u8, mem.span(name)) catch null;
            }
        },
        .capslock_enabled => {
            log.debug("<{*}> capslock_enabled", .{ xkb_keyboard });

            xkb_keyboard.capslock = .enabled;
        },
        .capslock_disabled => {
            log.debug("<{*}> capslock_disabled", .{ xkb_keyboard });

            xkb_keyboard.capslock = .disabled;
        },
        .numlock_enabled => {
            log.debug("<{*}> numlock_enabled", .{ xkb_keyboard });

            xkb_keyboard.numlock = .enabled;
        },
        .numlock_disabled => {
            log.debug("<{*}> numlock_disabled", .{ xkb_keyboard });

            xkb_keyboard.numlock = .disabled;
        },
        .removed => {
            log.debug("<{*}> removed", .{ xkb_keyboard });

            xkb_keyboard.destroy();
        }
    }
}


fn posix_write(fd: posix.fd_t, bytes: []const u8) !usize {
    if (bytes.len == 0) return 0;
    const max_count = 0x7ffff000;
    while (true) {
        const rc = posix.system.write(fd, bytes.ptr, @min(bytes.len, max_count));
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => return error.InvalidArgument,
            .FAULT => unreachable,
            .SRCH => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForWriting, // can be a race condition.
            .DESTADDRREQ => unreachable, // `connect` was never called.
            .DQUOT => return error.DiskQuota,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .NOSPC => return error.NoSpaceLeft,
            .ACCES => return error.AccessDenied,
            .PERM => return error.PermissionDenied,
            .PIPE => return error.BrokenPipe,
            .CONNRESET => return error.ConnectionResetByPeer,
            .BUSY => return error.DeviceBusy,
            .NXIO => return error.NoDevice,
            .MSGSIZE => return error.MessageTooBig,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}


fn posix_close(fd: posix.fd_t) void {
    switch (posix.errno(posix.system.close(fd))) {
        .BADF => unreachable, // Always a race condition.
        .INTR => return, // This is still a success. See https://github.com/ziglang/zig/issues/2425
        else => return,
    }
}
