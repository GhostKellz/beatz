const std = @import("std");
const root = @import("../root.zig");

pub const AudioDevice = root.AudioDevice;

// Temporarily disable C import until we can properly configure it
// const c = @cImport({
//     @cInclude("pipewire/pipewire.h");
//     @cInclude("pipewire/extensions/metadata.h");
// });

pub fn enumerateDevices(allocator: std.mem.Allocator) ![]AudioDevice {
    // TODO: Re-enable PipeWire C bindings once build system is properly configured
    // For now, detect if PipeWire is running via environment or socket check
    var devices = try std.ArrayList(AudioDevice).initCapacity(allocator, 1);

    // Check if PipeWire is available (basic detection)
    const pipewire_available = checkPipeWireAvailable();

    if (pipewire_available) {
        try devices.append(allocator, AudioDevice{
            .id = "pipewire_runtime",
            .name = "PipeWire Runtime Device",
            .is_default = true,
            .input_channels = 2,
            .output_channels = 2,
        });
    } else {
        try devices.append(allocator, AudioDevice{
            .id = "pipewire_fallback",
            .name = "PipeWire (Stub)",
            .is_default = true,
            .input_channels = 2,
            .output_channels = 2,
        });
    }

    return devices.toOwnedSlice(allocator);
}

fn checkPipeWireAvailable() bool {
    // Simple check for PipeWire availability
    if (std.process.getEnvVarOwned(std.heap.page_allocator, "PIPEWIRE_RUNTIME_DIR")) |_| {
        return true;
    } else |_| {}

    // Check for default socket location
    std.fs.accessAbsolute("/run/user/1000/pipewire-0", .{}) catch return false;
    return true;
}
