const std = @import("std");
const beatz = @import("beatz");

const WavPlayer = struct {
    audio_buffer: ?beatz.AudioBuffer = null,
    position: usize = 0,
    playing: bool = false,

    const Self = @This();

    pub fn loadFile(self: *Self, allocator: std.mem.Allocator, path: []const u8) !void {
        if (self.audio_buffer) |*buf| {
            buf.deinit();
        }
        self.audio_buffer = try beatz.AudioProcessor.loadFile(allocator, path);
        self.position = 0;
    }

    pub fn deinit(self: *Self) void {
        if (self.audio_buffer) |*buf| {
            buf.deinit();
        }
    }

    pub fn audioCallback(userdata: ?*anyopaque, input: ?[]const f32, output: []f32, frame_count: usize) void {
        _ = input;
        const player: *WavPlayer = @ptrCast(@alignCast(userdata.?));

        if (!player.playing or player.audio_buffer == null) {
            // Output silence
            for (0..frame_count * 2) |i| {
                output[i] = 0.0;
            }
            return;
        }

        const buffer = &player.audio_buffer.?;
        const channels = buffer.channels;

        for (0..frame_count) |frame| {
            for (0..channels) |channel| {
                const out_idx = frame * 2 + channel;
                const in_idx = player.position * channels + channel;

                if (in_idx < buffer.data.len) {
                    output[out_idx] = buffer.data[in_idx];
                } else {
                    output[out_idx] = 0.0;
                    player.playing = false;
                }
            }
            player.position += 1;
        }
    }

    pub fn play(self: *Self) void {
        self.playing = true;
        self.position = 0;
    }

    pub fn stop(self: *Self) void {
        self.playing = false;
    }

    pub fn isPlaying(self: Self) bool {
        return self.playing and self.audio_buffer != null;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <wav_file>\n", .{args[0]});
        std.debug.print("Example: {s} test.wav\n", .{args[0]});
        return;
    }

    const wav_path = args[1];

    std.debug.print("beatz WAV Player - Loading: {s}\n", .{wav_path});

    // Initialize audio context
    const config = beatz.AudioConfig{
        .sample_rate = 44100,
        .channels = 2,
        .buffer_size = 1024,
    };

    var ctx = try beatz.AudioContext.init(allocator, config);
    defer ctx.deinit();

    // Create WAV player
    var player = WavPlayer{};
    defer player.deinit();

    // Load WAV file
    player.loadFile(allocator, wav_path) catch |err| {
        std.debug.print("Error loading WAV file: {}\n", .{err});
        std.debug.print("Make sure the file exists and is a valid 16-bit PCM WAV file.\n", .{});
        return;
    };

    if (player.audio_buffer) |buffer| {
        const duration = @as(f32, @floatFromInt(buffer.data.len / buffer.channels)) / @as(f32, @floatFromInt(buffer.sample_rate));
        std.debug.print("Loaded: {} channels, {} Hz, {d:.2}s duration\n", .{ buffer.channels, buffer.sample_rate, duration });
    }

    // Create audio stream with our callback
    // Note: This is a simplified approach - in a real implementation we'd need better
    // state management for the callback
    const callback_data = struct {
        var global_player: ?*WavPlayer = null;

        fn callback(input: ?[]const f32, output: []f32, frame_count: usize) void {
            if (global_player) |p| {
                WavPlayer.audioCallback(p, input, output, frame_count);
            } else {
                // Output silence if no player
                for (0..frame_count * 2) |i| {
                    output[i] = 0.0;
                }
            }
        }
    };

    callback_data.global_player = &player;
    const callback = callback_data.callback;

    var stream = ctx.createStream(callback) catch |err| {
        std.debug.print("Failed to create audio stream: {}\n", .{err});
        return;
    };
    defer stream.deinit();

    std.debug.print("Starting playback... (this will play for a few seconds)\n", .{});

    // Start playback
    player.play();

    // Start the audio stream (this may block in some backends)
    stream.start() catch |err| {
        std.debug.print("Failed to start audio stream: {}\n", .{err});
        return;
    };

    // Keep playing while audio is active
    while (player.isPlaying()) {
        std.Thread.sleep(100_000_000); // Sleep 100ms
    }

    std.debug.print("Playback finished.\n", .{});
}