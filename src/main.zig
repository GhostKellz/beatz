const std = @import("std");
const beatz = @import("beatz");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    try beatz.bufferedPrint();

    // Test AudioContext
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = beatz.AudioConfig{
        .sample_rate = 44100,
        .channels = 2,
        .buffer_size = 512,
    };

    var ctx = try beatz.AudioContext.init(allocator, config);
    defer ctx.deinit();

    const devices = ctx.enumerateDevices();
    std.debug.print("Found {} audio devices:\n", .{devices.len});
    for (devices) |device| {
        std.debug.print("  - {s} (id: {s}, default: {})\n", .{ device.name, device.id, device.is_default });
    }
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
