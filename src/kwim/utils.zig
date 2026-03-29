const std = @import("std");

pub var allocator: std.mem.Allocator = undefined;


pub inline fn init_allocator(al: *const std.mem.Allocator) void {
    allocator = al.*;
}
