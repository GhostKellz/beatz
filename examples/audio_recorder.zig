const std = @import("std");
const beatz = @import("beatz");

const AudioRecorder = struct {
    recording: bool = false,
    recorded_samples: std.ArrayList(f32),
    sample_rate: u32,
    channels: u16,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, sample_rate: u32, channels: u16) Self {
        return Self{
            .recorded_samples = std.ArrayList(f32){},
            .sample_rate = sample_rate,
            .channels = channels,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.recorded_samples.deinit(self.allocator);
    }

    pub fn startRecording(self: *Self) void {
        self.recording = true;
        self.recorded_samples.clearAndFree(self.allocator);
        std.debug.print("Recording started...\n", .{});
    }

    pub fn stopRecording(self: *Self) void {
        self.recording = false;
        std.debug.print("Recording stopped. Captured {} samples\n", .{self.recorded_samples.items.len});
    }

    pub fn audioCallback(userdata: ?*anyopaque, input: ?[]const f32, output: []f32, frame_count: usize) void {
        const recorder: *AudioRecorder = @ptrCast(@alignCast(userdata.?));

        // Clear output (we're recording, not playing)
        for (0..frame_count * 2) |i| {
            output[i] = 0.0;
        }

        if (!recorder.recording or input == null) {
            return;
        }

        const input_data = input.?;

        // Record input samples
        for (0..frame_count * recorder.channels) |i| {
            if (i < input_data.len) {
                recorder.recorded_samples.append(recorder.allocator, input_data[i]) catch {
                    // Handle memory allocation failure gracefully
                    std.debug.print("Warning: Failed to allocate memory for recording\n", .{});
                    return;
                };
            }
        }
    }

    pub fn saveToWav(self: *Self, filename: []const u8) !void {
        if (self.recorded_samples.items.len == 0) {
            std.debug.print("No audio data to save\n", .{});
            return;
        }

        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        // WAV header
        const data_size = self.recorded_samples.items.len * 2; // 16-bit samples
        const file_size = 36 + data_size;

        // Write WAV header manually
        try file.writeAll("RIFF");

        // Write file size as bytes
        const file_size_bytes = std.mem.toBytes(@as(u32, @intCast(file_size)));
        try file.writeAll(file_size_bytes[0..]);

        try file.writeAll("WAVE");
        try file.writeAll("fmt ");

        // Write format chunk size
        const fmt_size_bytes = std.mem.toBytes(@as(u32, 16));
        try file.writeAll(fmt_size_bytes[0..]);

        // Write format data
        const pcm_bytes = std.mem.toBytes(@as(u16, 1));
        try file.writeAll(pcm_bytes[0..]);

        const channels_bytes = std.mem.toBytes(self.channels);
        try file.writeAll(channels_bytes[0..]);

        const sample_rate_bytes = std.mem.toBytes(self.sample_rate);
        try file.writeAll(sample_rate_bytes[0..]);

        const byte_rate = self.sample_rate * self.channels * 2;
        const byte_rate_bytes = std.mem.toBytes(byte_rate);
        try file.writeAll(byte_rate_bytes[0..]);

        const block_align = self.channels * 2;
        const block_align_bytes = std.mem.toBytes(block_align);
        try file.writeAll(block_align_bytes[0..]);

        const bits_per_sample_bytes = std.mem.toBytes(@as(u16, 16));
        try file.writeAll(bits_per_sample_bytes[0..]);

        // Data chunk
        try file.writeAll("data");
        const data_size_bytes = std.mem.toBytes(@as(u32, @intCast(data_size)));
        try file.writeAll(data_size_bytes[0..]);

        // Convert f32 samples to 16-bit and write
        for (self.recorded_samples.items) |sample| {
            const clamped = std.math.clamp(sample, -1.0, 1.0);
            const sample_i16 = @as(i16, @intFromFloat(clamped * 32767.0));
            const sample_bytes = std.mem.toBytes(sample_i16);
            try file.writeAll(sample_bytes[0..]);
        }

        std.debug.print("Audio saved to {s}\n", .{filename});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var duration: u32 = 5; // Default 5 seconds
    var output_file: []const u8 = "recording.wav";

    if (args.len > 1) {
        duration = std.fmt.parseInt(u32, args[1], 10) catch blk: {
            std.debug.print("Invalid duration. Using default 5 seconds.\n", .{});
            break :blk 5;
        };
    }

    if (args.len > 2) {
        output_file = args[2];
    }

    std.debug.print("beatz Audio Recorder\n", .{});
    std.debug.print("Recording for {} seconds to {s}\n", .{ duration, output_file });

    // Initialize audio context for recording
    const config = beatz.AudioConfig{
        .sample_rate = 44100,
        .channels = 2,
        .buffer_size = 1024,
    };

    var ctx = try beatz.AudioContext.init(allocator, config);
    defer ctx.deinit();

    // Create audio recorder
    var recorder = AudioRecorder.init(allocator, config.sample_rate, config.channels);
    defer recorder.deinit();

    // Check for input devices
    const input_device = ctx.getDefaultInputDevice();
    if (input_device == null) {
        std.debug.print("No input device available for recording\n", .{});
        return;
    }

    std.debug.print("Using input device: {s}\n", .{input_device.?.name});

    // Create audio stream with our callback
    const callback_data = struct {
        var global_recorder: ?*AudioRecorder = null;

        fn callback(input: ?[]const f32, output: []f32, frame_count: usize) void {
            if (global_recorder) |r| {
                AudioRecorder.audioCallback(r, input, output, frame_count);
            } else {
                // Output silence if no recorder
                for (0..frame_count * 2) |i| {
                    output[i] = 0.0;
                }
            }
        }
    };

    callback_data.global_recorder = &recorder;
    const callback = callback_data.callback;

    var stream = ctx.createStream(callback) catch |err| {
        std.debug.print("Failed to create audio stream: {}\n", .{err});
        return;
    };
    defer stream.deinit();

    // Start recording
    recorder.startRecording();

    // Start the audio stream
    stream.start() catch |err| {
        std.debug.print("Failed to start audio stream: {}\n", .{err});
        return;
    };

    // Record for specified duration
    std.Thread.sleep(duration * 1_000_000_000); // Convert seconds to nanoseconds

    // Stop recording
    recorder.stopRecording();

    // Save to WAV file
    try recorder.saveToWav(output_file);

    std.debug.print("Recording complete!\n", .{});
}