const std = @import("std");
const root = @import("../root.zig");

pub const AudioDevice = root.AudioDevice;

pub const ALSABackend = struct {
    // TODO: implement ALSA bindings
};

pub fn enumerateDevices(allocator: std.mem.Allocator) ![]AudioDevice {
    var devices = try std.ArrayList(AudioDevice).initCapacity(allocator, 1);
    try devices.append(allocator, AudioDevice{
        .id = "alsa_default",
        .name = "ALSA Default Device",
        .is_default = true,
        .input_channels = 2,
        .output_channels = 2,
    });
    return devices.toOwnedSlice(allocator);
}
