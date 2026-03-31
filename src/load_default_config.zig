const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const heap = std.heap;
const process = std.process;


pub fn main() !void {
    var input: ?[]const u8 = null;
    var output: ?[]const u8 = null;

    var it = process.args();
    while (it.next()) |arg| {
        if (mem.eql(u8, arg, "-i")) {
            input = it.next();
        } else if (mem.eql(u8, arg, "-o")) {
            output = it.next();
        }
    }

    const input_file = try fs.cwd().openFile(
        input orelse return error.MissingInput,
        .{ .mode = .read_only },
    );
    defer input_file.close();
    var input_buffer: [1024]u8 = undefined;
    var input_reader = input_file.reader(&input_buffer);
    const input_interface = &input_reader.interface;

    const output_file = try fs.createFileAbsolute(
        output orelse return error.MissingOutput,
        .{},
    );
    defer output_file.close();
    var output_buffer: [1024]u8 = undefined;
    var output_writer = output_file.writer(&output_buffer);
    const output_interface = &output_writer.interface;

    try output_interface.writeAll(".{\n");

    var save = false;
    while (input_interface.takeDelimiterInclusive('\n')) |line| {
        if (mem.indexOf(u8, line, "@if(kewuaa=super_hansome)") != null) {
            save = true;
        }
        if (save) {
            try output_interface.writeAll(line);
        }
    } else |err| if (err != error.EndOfStream) return err;

    try output_interface.flush();
}
