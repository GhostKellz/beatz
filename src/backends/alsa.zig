const std = @import("std");
const root = @import("../root.zig");

pub const AudioDevice = root.AudioDevice;

const c = @cImport({
    @cInclude("alsa/asoundlib.h");
});

pub const ALSAMixer = struct {
    handle: ?*c.snd_mixer_t = null,
    master_elem: ?*c.snd_mixer_elem_t = null,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, card_name: []const u8) !Self {
        var mixer: ?*c.snd_mixer_t = null;

        // Open mixer
        var open_result = c.snd_mixer_open(&mixer, 0);
        if (open_result < 0) {
            return error.MixerOpenFailed;
        }

        // Attach to card
        const card_name_z = try allocator.dupeZ(u8, card_name);
        defer allocator.free(card_name_z);

        open_result = c.snd_mixer_attach(mixer, card_name_z.ptr);
        if (open_result < 0) {
            _ = c.snd_mixer_close(mixer);
            return error.MixerAttachFailed;
        }

        // Register mixer
        open_result = c.snd_mixer_selem_register(mixer, null, null);
        if (open_result < 0) {
            _ = c.snd_mixer_close(mixer);
            return error.MixerRegisterFailed;
        }

        // Load mixer elements
        open_result = c.snd_mixer_load(mixer);
        if (open_result < 0) {
            _ = c.snd_mixer_close(mixer);
            return error.MixerLoadFailed;
        }

        // Find master element
        var master_elem: ?*c.snd_mixer_elem_t = null;
        var elem = c.snd_mixer_first_elem(mixer);
        while (elem != null) {
            const elem_name = c.snd_mixer_selem_get_name(elem);
            if (std.mem.orderZ(u8, elem_name, "Master") == .eq) {
                master_elem = elem;
                break;
            }
            elem = c.snd_mixer_elem_next(elem);
        }

        return Self{
            .handle = mixer,
            .master_elem = master_elem,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.handle) |handle| {
            _ = c.snd_mixer_close(handle);
        }
    }

    pub fn getVolume(self: *Self) !f32 {
        if (self.master_elem == null) return error.NoMasterElement;

        var volume: c_long = 0;
        var min: c_long = 0;
        var max: c_long = 0;

        _ = c.snd_mixer_selem_get_playback_volume_range(self.master_elem, &min, &max);
        _ = c.snd_mixer_selem_get_playback_volume(self.master_elem, c.SND_MIXER_SCHN_MONO, &volume);

        if (max == min) return 0.0;
        return @as(f32, @floatFromInt(volume - min)) / @as(f32, @floatFromInt(max - min));
    }

    pub fn setVolume(self: *Self, volume: f32) !void {
        if (self.master_elem == null) return error.NoMasterElement;

        var min: c_long = 0;
        var max: c_long = 0;
        _ = c.snd_mixer_selem_get_playback_volume_range(self.master_elem, &min, &max);

        const clamped_volume = std.math.clamp(volume, 0.0, 1.0);
        const target_volume = min + @as(c_long, @intFromFloat(clamped_volume * @as(f32, @floatFromInt(max - min))));

        const result = c.snd_mixer_selem_set_playback_volume_all(self.master_elem, target_volume);
        if (result < 0) {
            return error.VolumeSetFailed;
        }
    }

    pub fn getMute(self: *Self) !bool {
        if (self.master_elem == null) return error.NoMasterElement;

        var mute: c_int = 0;
        _ = c.snd_mixer_selem_get_playback_switch(self.master_elem, c.SND_MIXER_SCHN_MONO, &mute);
        return mute == 0; // ALSA uses 0 for muted, 1 for unmuted
    }

    pub fn setMute(self: *Self, muted: bool) !void {
        if (self.master_elem == null) return error.NoMasterElement;

        const alsa_mute_value: c_int = if (muted) 0 else 1;
        const result = c.snd_mixer_selem_set_playback_switch_all(self.master_elem, alsa_mute_value);
        if (result < 0) {
            return error.MuteSetFailed;
        }
    }
};

pub const ALSABackend = struct {
    handle: ?*c.snd_pcm_t = null,
    mixer: ?ALSAMixer = null,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Try to initialize mixer for default card
        const mixer: ?ALSAMixer = ALSAMixer.init(allocator, "default") catch null;

        return Self{
            .handle = null,
            .mixer = mixer,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.handle) |handle| {
            _ = c.snd_pcm_close(handle);
        }
        if (self.mixer) |*mixer| {
            mixer.deinit();
        }
    }

    pub fn getMixer(self: *Self) ?*ALSAMixer {
        if (self.mixer) |*mixer| {
            return mixer;
        }
        return null;
    }
};

pub const ALSAStream = struct {
    handle: ?*c.snd_pcm_t = null,
    config: root.AudioConfig,
    callback: ?root.AudioCallback = null,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: root.AudioConfig, callback: root.AudioCallback) !Self {
        var handle: ?*c.snd_pcm_t = null;

        // Open ALSA device
        const open_result = c.snd_pcm_open(&handle, "default", c.SND_PCM_STREAM_PLAYBACK, 0);
        if (open_result < 0) {
            std.debug.print("ALSA: Cannot open audio device: {s}\n", .{c.snd_strerror(open_result)});
            return error.ALSAOpenFailed;
        }

        // Set hardware parameters with optimization
        var params: ?*c.snd_pcm_hw_params_t = null;
        _ = c.snd_pcm_hw_params_malloc(&params);
        defer c.snd_pcm_hw_params_free(params);

        _ = c.snd_pcm_hw_params_any(handle, params);
        _ = c.snd_pcm_hw_params_set_access(handle, params, c.SND_PCM_ACCESS_RW_INTERLEAVED);
        _ = c.snd_pcm_hw_params_set_format(handle, params, c.SND_PCM_FORMAT_S16_LE);
        _ = c.snd_pcm_hw_params_set_channels(handle, params, config.channels);

        var rate = config.sample_rate;
        _ = c.snd_pcm_hw_params_set_rate_near(handle, params, &rate, null);

        // Optimize buffer and period sizes for low latency
        // Calculate optimal period size (target: 1/4 of buffer size)
        const target_period_frames = config.buffer_size / 4;
        var period_size: c.snd_pcm_uframes_t = target_period_frames;
        var dir: c_int = 0;

        // Set period size (try to get close to target)
        var period_result = c.snd_pcm_hw_params_set_period_size_near(handle, params, &period_size, &dir);
        if (period_result < 0) {
            std.debug.print("ALSA: Warning - cannot set period size: {s}\n", .{c.snd_strerror(period_result)});
            // Continue anyway - ALSA will use defaults
        }

        // Set buffer size (4 periods is a good default for low latency)
        var buffer_size: c.snd_pcm_uframes_t = period_size * 4;
        const buffer_result = c.snd_pcm_hw_params_set_buffer_size_near(handle, params, &buffer_size);
        if (buffer_result < 0) {
            std.debug.print("ALSA: Warning - cannot set buffer size: {s}\n", .{c.snd_strerror(buffer_result)});
            // Continue anyway
        }

        // Try to minimize period time for lower latency
        var period_time: c_uint = 10000; // 10ms in microseconds
        dir = -1; // prefer smaller values
        period_result = c.snd_pcm_hw_params_set_period_time_near(handle, params, &period_time, &dir);
        if (period_result < 0) {
            std.debug.print("ALSA: Warning - cannot set period time: {s}\n", .{c.snd_strerror(period_result)});
        }

        const set_params_result = c.snd_pcm_hw_params(handle, params);
        if (set_params_result < 0) {
            _ = c.snd_pcm_close(handle);
            std.debug.print("ALSA: Cannot set hardware parameters: {s}\n", .{c.snd_strerror(set_params_result)});
            return error.ALSAConfigFailed;
        }

        // Get actual values and report optimization results
        var actual_period_size: c.snd_pcm_uframes_t = 0;
        var actual_buffer_size: c.snd_pcm_uframes_t = 0;
        var actual_period_time: c_uint = 0;

        _ = c.snd_pcm_hw_params_get_period_size(params, &actual_period_size, &dir);
        _ = c.snd_pcm_hw_params_get_buffer_size(params, &actual_buffer_size);
        _ = c.snd_pcm_hw_params_get_period_time(params, &actual_period_time, &dir);

        std.debug.print("ALSA Optimization: period={} frames, buffer={} frames, period_time={}μs\n",
                       .{actual_period_size, actual_buffer_size, actual_period_time});

        // Set software parameters for further optimization
        var sw_params: ?*c.snd_pcm_sw_params_t = null;
        _ = c.snd_pcm_sw_params_malloc(&sw_params);
        defer c.snd_pcm_sw_params_free(sw_params);

        _ = c.snd_pcm_sw_params_current(handle, sw_params);

        // Start threshold - start playback when buffer has enough data
        _ = c.snd_pcm_sw_params_set_start_threshold(handle, sw_params, actual_period_size);

        // Stop threshold - stop when buffer is empty
        _ = c.snd_pcm_sw_params_set_stop_threshold(handle, sw_params, actual_buffer_size);

        // Available minimum - wake up when at least one period is available
        _ = c.snd_pcm_sw_params_set_avail_min(handle, sw_params, actual_period_size);

        const sw_result = c.snd_pcm_sw_params(handle, sw_params);
        if (sw_result < 0) {
            std.debug.print("ALSA: Warning - cannot set software parameters: {s}\n", .{c.snd_strerror(sw_result)});
        }

        const prepare_result = c.snd_pcm_prepare(handle);
        if (prepare_result < 0) {
            _ = c.snd_pcm_close(handle);
            std.debug.print("ALSA: Cannot prepare audio interface: {s}\n", .{c.snd_strerror(prepare_result)});
            return error.ALSAPrepareFailed;
        }

        return Self{
            .handle = handle,
            .config = config,
            .callback = callback,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.handle) |handle| {
            _ = c.snd_pcm_close(handle);
        }
    }

    pub fn start(self: *Self) !void {
        // Simple test: play silence for a moment
        if (self.handle) |handle| {
            const buffer_size = 1024;
            const buffer = try self.allocator.alloc(i16, buffer_size * self.config.channels);
            defer self.allocator.free(buffer);

            // Fill buffer with silence
            for (buffer) |*sample| {
                sample.* = 0;
            }

            // Write some frames
            for (0..10) |_| {
                const frames_written = c.snd_pcm_writei(handle, buffer.ptr, buffer_size);
                if (frames_written < 0) {
                    const recover_result = c.snd_pcm_recover(handle, @intCast(frames_written), 0);
                    if (recover_result < 0) {
                        std.debug.print("ALSA: Write error: {s}\n", .{c.snd_strerror(@intCast(frames_written))});
                        return error.ALSAWriteFailed;
                    }
                }
            }

            _ = c.snd_pcm_drain(handle);
        }
    }
};

pub fn enumerateDevices(allocator: std.mem.Allocator) ![]AudioDevice {
    var devices = try std.ArrayList(AudioDevice).initCapacity(allocator, 2);

    // Add default device
    try devices.append(allocator, AudioDevice{
        .id = try allocator.dupe(u8, "default"),
        .name = try allocator.dupe(u8, "ALSA Default Device"),
        .is_default = true,
        .input_channels = 2,
        .output_channels = 2,
    });

    // Try to enumerate actual ALSA devices
    var card: c_int = -1;
    while (c.snd_card_next(&card) >= 0 and card >= 0) {
        const card_name_buf = try std.fmt.allocPrint(allocator, "hw:{}", .{card});
        defer allocator.free(card_name_buf);

        var card_name: [*c]u8 = undefined;
        if (c.snd_card_get_name(card, &card_name) >= 0) {
            const device_name = try std.fmt.allocPrint(allocator, "ALSA Card {}: {s}", .{ card, card_name });
            const device_id = try std.fmt.allocPrint(allocator, "hw:{}", .{card});

            try devices.append(allocator, AudioDevice{
                .id = device_id,
                .name = device_name,
                .is_default = false,
                .input_channels = 2,
                .output_channels = 2,
            });

            c.free(card_name);
        }
    }

    return try devices.toOwnedSlice(allocator);
}
