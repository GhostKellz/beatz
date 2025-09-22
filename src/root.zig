const std = @import("std");

const builtin = @import("builtin");
const target = builtin.target;

pub const AudioConfig = struct {
    sample_rate: u32 = 44100,
    channels: u16 = 2,
    buffer_size: usize = 1024,
};

pub const AudioDevice = struct {
    id: []const u8,
    name: []const u8,
    is_default: bool = false,
    input_channels: u16 = 0,
    output_channels: u16 = 0,
};

pub const AudioBuffer = struct {
    data: []f32,
    sample_rate: u32,
    channels: u16,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *AudioBuffer) void {
        self.allocator.free(self.data);
    }
};

pub const AudioCallback = fn (input: ?[]const f32, output: []f32, frame_count: usize) void;

pub const Effect = union(enum) {
    volume: f32,
    delay: struct { delay_ms: f32, feedback: f32 },
    reverb: struct { room_size: f32, damping: f32 },
};

pub const SynthConfig = struct {
    oscillator: OscillatorType = .sine,
    frequency: f32 = 440.0,
    amplitude: f32 = 0.5,
};

pub const OscillatorType = enum {
    sine,
    square,
    triangle,
    sawtooth,
};

pub const AudioContext = struct {
    allocator: std.mem.Allocator,
    config: AudioConfig,
    devices: std.ArrayList(AudioDevice),

    pub fn init(allocator: std.mem.Allocator, config: AudioConfig) !AudioContext {
        var devices = try std.ArrayList(AudioDevice).initCapacity(allocator, 0);

        // Enumerate devices from platform backend
        if (target.os.tag == .linux) {
            const pipewire = @import("backends/pipewire.zig");
            if (pipewire.enumerateDevices(allocator)) |backend_devices| {
                try devices.appendSlice(allocator, backend_devices);
                allocator.free(backend_devices);
            } else |_| {
                // Fallback to ALSA
                const alsa = @import("backends/alsa.zig");
                if (alsa.enumerateDevices(allocator)) |alsa_devices| {
                    try devices.appendSlice(allocator, alsa_devices);
                    allocator.free(alsa_devices);
                } else |_| {
                    // Both failed, add dummy
                    try devices.append(allocator, AudioDevice{
                        .id = "fallback",
                        .name = "Fallback Audio Device",
                        .is_default = true,
                        .input_channels = 2,
                        .output_channels = 2,
                    });
                }
            }
        } else {
            // For other platforms, add dummy device
            try devices.append(allocator, AudioDevice{
                .id = "default",
                .name = "Default Audio Device",
                .is_default = true,
                .input_channels = 2,
                .output_channels = 2,
            });
        }

        return AudioContext{
            .allocator = allocator,
            .config = config,
            .devices = devices,
        };
    }

    pub fn deinit(self: *AudioContext) void {
        self.devices.deinit(self.allocator);
    }

    pub fn createStream(self: *AudioContext, callback: AudioCallback) !AudioStream {
        _ = self;
        _ = callback; // TODO: implement
        return AudioStream{};
    }

    pub fn enumerateDevices(self: AudioContext) []AudioDevice {
        return self.devices.items;
    }
};

pub const AudioStream = struct {
    // TODO: implement stream functionality
};

pub const AudioProcessor = struct {
    pub fn loadFile(allocator: std.mem.Allocator, path: []const u8) !AudioBuffer {
        // TODO: detect format by extension or magic bytes
        // For now, assume WAV
        return loadWavFile(allocator, path);
    }

    fn loadWavFile(allocator: std.mem.Allocator, path: []const u8) !AudioBuffer {
        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        var reader = file.reader();

        // Read WAV header
        var header: [44]u8 = undefined;
        _ = try reader.read(&header);

        // Check "RIFF" and "WAVE"
        if (!std.mem.eql(u8, header[0..4], "RIFF")) return error.InvalidFormat;
        if (!std.mem.eql(u8, header[8..12], "WAVE")) return error.InvalidFormat;

        // Read format chunk
        const audio_format = std.mem.readInt(u16, header[20..22], .little);
        if (audio_format != 1) return error.UnsupportedFormat; // PCM

        const channels = std.mem.readInt(u16, header[22..24], .little);
        const sample_rate = std.mem.readInt(u32, header[24..28], .little);
        const bits_per_sample = std.mem.readInt(u16, header[34..36], .little);
        if (bits_per_sample != 16) return error.UnsupportedFormat; // For now, 16-bit

        const data_size = std.mem.readInt(u32, header[40..44], .little);
        const num_samples = data_size / (bits_per_sample / 8) / channels;

        // Read data
        const data_bytes = try allocator.alloc(u8, data_size);
        defer allocator.free(data_bytes);
        _ = try reader.read(data_bytes);

        // Convert to f32
        const data = try allocator.alloc(f32, num_samples * channels);
        for (0..num_samples * channels) |i| {
            const sample_i16 = std.mem.readInt(i16, data_bytes[i * 2 .. i * 2 + 2], .little);
            data[i] = @as(f32, @floatFromInt(sample_i16)) / 32768.0;
        }

        return AudioBuffer{
            .data = data,
            .sample_rate = sample_rate,
            .channels = channels,
            .allocator = allocator,
        };
    }

    // NOTE: Effects and synthesis moved to zdsp library to avoid overlap
    // Basic format loading remains in beatz for I/O purposes
};

pub fn bufferedPrint() !void {
    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.flush(); // Don't forget to flush!
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
