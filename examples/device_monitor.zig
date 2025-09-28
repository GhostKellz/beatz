const std = @import("std");
const beatz = @import("beatz");

const DeviceMonitor = struct {
    allocator: std.mem.Allocator,
    running: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn start(self: *Self, ctx: *beatz.AudioContext) !void {
        self.running = true;

        // Set up device change callback
        ctx.setDeviceChangeCallback(deviceChangeCallback);

        std.debug.print("beatz Device Monitor\n", .{});
        std.debug.print("====================\n", .{});
        std.debug.print("Monitoring audio device changes...\n", .{});
        std.debug.print("Press Ctrl+C to exit\n\n", .{});

        // List current devices
        self.listDevices(ctx);

        // Note: In a real implementation, we would set up the PipeWire device monitoring
        // For now, we'll just wait and list devices periodically
        while (self.running) {
            std.Thread.sleep(5_000_000_000); // 5 seconds
            std.debug.print("\n--- Device List Update ---\n", .{});
            self.listDevices(ctx);
        }
    }

    pub fn stop(self: *Self) void {
        self.running = false;
        std.debug.print("Device monitoring stopped.\n", .{});
    }

    fn listDevices(self: *Self, ctx: *beatz.AudioContext) void {
        _ = self;
        const devices = ctx.enumerateDevices();

        std.debug.print("Available Audio Devices:\n", .{});
        std.debug.print("========================\n", .{});

        if (devices.len == 0) {
            std.debug.print("No audio devices found.\n", .{});
            return;
        }

        for (devices, 0..) |device, i| {
            std.debug.print("Device {}: {s}\n", .{ i + 1, device.name });
            std.debug.print("  ID: {s}\n", .{device.id});
            std.debug.print("  Default: {}\n", .{device.is_default});
            std.debug.print("  Input Channels: {}\n", .{device.input_channels});
            std.debug.print("  Output Channels: {}\n", .{device.output_channels});

            if (device.capabilities) |caps| {
                std.debug.print("  Capabilities:\n", .{});
                std.debug.print("    Channel Range: {} - {}\n", .{ caps.min_channels, caps.max_channels });
                std.debug.print("    Buffer Range: {} - {} frames\n", .{ caps.min_buffer_size, caps.max_buffer_size });
                std.debug.print("    Latency Range: {} - {} μs\n", .{ caps.min_latency_us, caps.max_latency_us });

                std.debug.print("    Sample Rates: ", .{});
                for (caps.supported_sample_rates, 0..) |rate, idx| {
                    if (idx > 0) std.debug.print(", ", .{});
                    std.debug.print("{}Hz", .{rate});
                }
                std.debug.print("\n", .{});

                std.debug.print("    Formats: ", .{});
                for (caps.supported_formats, 0..) |format, idx| {
                    if (idx > 0) std.debug.print(", ", .{});
                    std.debug.print("{s}", .{@tagName(format)});
                }
                std.debug.print("\n", .{});
            }
            std.debug.print("\n", .{});
        }

        // Show default devices
        if (ctx.getDefaultOutputDevice()) |default_out| {
            std.debug.print("Default Output Device: {s}\n", .{default_out.name});
        }

        if (ctx.getDefaultInputDevice()) |default_in| {
            std.debug.print("Default Input Device: {s}\n", .{default_in.name});
        }

        std.debug.print("\n", .{});
    }

    fn deviceChangeCallback(event: beatz.DeviceChangeEvent, device: ?*const beatz.AudioDevice) void {
        const timestamp = std.time.timestamp();
        const day_seconds = @mod(timestamp, 86400);
        const hours = @divTrunc(day_seconds, 3600);
        const minutes = @divTrunc(@mod(day_seconds, 3600), 60);
        const seconds = @mod(day_seconds, 60);

        std.debug.print("[{:02}:{:02}:{:02}] Device Event: ", .{ hours, minutes, seconds });

        switch (event) {
            .device_added => {
                if (device) |dev| {
                    std.debug.print("ADDED - {s} ({s})\n", .{ dev.name, dev.id });
                } else {
                    std.debug.print("ADDED - Unknown device\n", .{});
                }
            },
            .device_removed => {
                if (device) |dev| {
                    std.debug.print("REMOVED - {s} ({s})\n", .{ dev.name, dev.id });
                } else {
                    std.debug.print("REMOVED - Unknown device\n", .{});
                }
            },
            .device_changed => {
                if (device) |dev| {
                    std.debug.print("CHANGED - {s} ({s})\n", .{ dev.name, dev.id });
                } else {
                    std.debug.print("CHANGED - Unknown device\n", .{});
                }
            },
            .default_changed => {
                if (device) |dev| {
                    std.debug.print("DEFAULT CHANGED - {s} ({s})\n", .{ dev.name, dev.id });
                } else {
                    std.debug.print("DEFAULT CHANGED - No default device\n", .{});
                }
            },
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize audio context
    const config = beatz.AudioConfig{
        .sample_rate = 44100,
        .channels = 2,
        .buffer_size = 1024,
    };

    var ctx = try beatz.AudioContext.init(allocator, config);
    defer ctx.deinit();

    // Create device monitor
    var monitor = DeviceMonitor.init(allocator);

    // Set up signal handler for graceful shutdown
    // Note: In a production application, you'd want proper signal handling
    // For now, we'll just run and let the user interrupt with Ctrl+C

    // Start monitoring
    try monitor.start(&ctx);
}