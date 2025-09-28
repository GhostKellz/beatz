const std = @import("std");
const root = @import("../root.zig");

pub const AudioDevice = root.AudioDevice;

const c = @cImport({
    @cInclude("pipewire/pipewire.h");
    @cInclude("pipewire/extensions/metadata.h");
    @cInclude("spa/param/audio/format-utils.h");
    @cInclude("spa/param/props.h");
});

pub const DeviceEventCallback = *const fn(event: DeviceEvent, device: AudioDevice) void;

pub const DeviceEvent = enum {
    added,
    removed,
    changed,
};

pub const PipeWireBackend = struct {
    loop: ?*c.pw_main_loop,
    context: ?*c.pw_context,
    core: ?*c.pw_core,
    registry: ?*c.pw_registry,
    allocator: std.mem.Allocator,
    device_callback: ?DeviceEventCallback = null,
    registry_listener: c.spa_hook = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        c.pw_init(null, null);

        const loop = c.pw_main_loop_new(null) orelse return error.PipeWireInitFailed;
        const context = c.pw_context_new(c.pw_main_loop_get_loop(loop), null, 0) orelse {
            c.pw_main_loop_destroy(loop);
            return error.PipeWireInitFailed;
        };

        const core = c.pw_context_connect(context, null, 0) orelse {
            c.pw_context_destroy(context);
            c.pw_main_loop_destroy(loop);
            return error.PipeWireInitFailed;
        };

        return Self{
            .loop = loop,
            .context = context,
            .core = core,
            .registry = null,
            .allocator = allocator,
            .device_callback = null,
            .registry_listener = std.mem.zeroes(c.spa_hook),
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.registry) |registry| {
            c.pw_proxy_destroy(@ptrCast(registry));
        }
        if (self.core) |core| {
            _ = c.pw_core_disconnect(core);
        }
        if (self.context) |context| {
            c.pw_context_destroy(context);
        }
        if (self.loop) |loop| {
            c.pw_main_loop_destroy(loop);
        }
        c.pw_deinit();
    }

    pub fn setDeviceCallback(self: *Self, callback: DeviceEventCallback) !void {
        self.device_callback = callback;

        // Create registry if not already created
        if (self.registry == null) {
            self.registry = c.pw_core_get_registry(self.core, c.PW_VERSION_REGISTRY, 0);
            if (self.registry == null) {
                return error.RegistryCreateFailed;
            }
        }

        // Set up registry listener
        const registry_events = c.pw_registry_events{
            .version = c.PW_VERSION_REGISTRY_EVENTS,
            .global = registryGlobalCallback,
            .global_remove = registryGlobalRemoveCallback,
        };

        c.pw_registry_add_listener(self.registry, &self.registry_listener, &registry_events, self);
    }

    pub fn startDeviceMonitoring(self: *Self) !void {
        if (self.loop) |loop| {
            // Run one iteration to process initial events
            c.pw_main_loop_run(loop);
        }
    }

    fn registryGlobalCallback(data: ?*anyopaque, id: u32, permissions: u32, type_name: [*c]const u8, version: u32, props: ?*const c.spa_dict) callconv(.C) void {
        _ = id;
        _ = permissions;
        _ = version;

        const self: *Self = @ptrCast(@alignCast(data.?));

        if (std.mem.orderZ(u8, type_name, c.PW_TYPE_INTERFACE_Node) == .eq) {
            // This is a node (potential audio device)
            if (props) |properties| {
                const device = parseNodeProperties(self.allocator, properties) catch return;

                if (self.device_callback) |callback| {
                    callback(DeviceEvent.added, device);
                }
            }
        }
    }

    fn registryGlobalRemoveCallback(data: ?*anyopaque, id: u32) callconv(.C) void {
        _ = id;
        const self: *Self = @ptrCast(@alignCast(data.?));

        // For simplicity, we'll create a dummy device for removal events
        // In a full implementation, we'd track devices by ID
        const dummy_device = AudioDevice{
            .id = "removed",
            .name = "Removed Device",
            .is_default = false,
            .input_channels = 0,
            .output_channels = 0,
        };

        if (self.device_callback) |callback| {
            callback(DeviceEvent.removed, dummy_device);
        }
    }

    fn parseNodeProperties(allocator: std.mem.Allocator, props: *const c.spa_dict) !AudioDevice {
        _ = props;

        // For now, return a basic device
        // In a full implementation, we'd parse the actual properties
        return AudioDevice{
            .id = try allocator.dupe(u8, "hotplug_device"),
            .name = try allocator.dupe(u8, "Hotplug Audio Device"),
            .is_default = false,
            .input_channels = 2,
            .output_channels = 2,
        };
    }
};

pub const PipeWireStream = struct {
    stream: ?*c.pw_stream,
    loop: ?*c.pw_main_loop,
    context: ?*c.pw_context,
    callback: ?root.AudioCallback,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: root.AudioConfig, callback: root.AudioCallback) !Self {
        _ = allocator;
        _ = config;
        c.pw_init(null, null);

        const loop = c.pw_main_loop_new(null) orelse return error.PipeWireInitFailed;
        const context = c.pw_context_new(c.pw_main_loop_get_loop(loop), null, 0) orelse {
            c.pw_main_loop_destroy(loop);
            return error.PipeWireInitFailed;
        };

        const core = c.pw_context_connect(context, null, 0) orelse {
            c.pw_context_destroy(context);
            c.pw_main_loop_destroy(loop);
            return error.PipeWireInitFailed;
        };

        const stream_events = c.pw_stream_events{
            .version = c.PW_VERSION_STREAM_EVENTS,
            .destroy = null,
            .state_changed = streamStateChanged,
            .control_info = null,
            .io_changed = null,
            .param_changed = null,
            .add_buffer = null,
            .remove_buffer = null,
            .process = streamProcess,
            .drained = null,
            .command = null,
            .trigger_done = null,
        };

        const stream = c.pw_stream_new_simple(
            c.pw_main_loop_get_loop(loop),
            "beatz-stream",
            c.pw_properties_new(
                c.PW_KEY_MEDIA_TYPE, "Audio",
                c.PW_KEY_MEDIA_CATEGORY, "Playback",
                c.PW_KEY_MEDIA_ROLE, "Music",
                @as([*c]const u8, null),
            ),
            &stream_events,
            @as(?*anyopaque, null),
        ) orelse {
            _ = c.pw_core_disconnect(core);
            c.pw_context_destroy(context);
            c.pw_main_loop_destroy(loop);
            return error.PipeWireInitFailed;
        };

        // For now, connect without specific format params to test basic functionality
        const connect_result = c.pw_stream_connect(
            stream,
            c.PW_DIRECTION_OUTPUT,
            c.PW_ID_ANY,
            c.PW_STREAM_FLAG_AUTOCONNECT,
            null,
            0,
        );

        if (connect_result < 0) {
            c.pw_stream_destroy(stream);
            _ = c.pw_core_disconnect(core);
            c.pw_context_destroy(context);
            c.pw_main_loop_destroy(loop);
            return error.PipeWireConnectFailed;
        }

        return Self{
            .stream = stream,
            .loop = loop,
            .context = context,
            .callback = callback,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.stream) |stream| {
            c.pw_stream_destroy(stream);
        }
        if (self.context) |context| {
            c.pw_context_destroy(context);
        }
        if (self.loop) |loop| {
            c.pw_main_loop_destroy(loop);
        }
        c.pw_deinit();
    }

    pub fn start(self: *Self) !void {
        if (self.loop) |loop| {
            _ = c.pw_main_loop_run(loop);
        }
    }

    fn streamStateChanged(data: ?*anyopaque, old: c.pw_stream_state, state: c.pw_stream_state, error_msg: [*c]const u8) callconv(.c) void {
        _ = data;
        _ = old;
        _ = error_msg;
        std.debug.print("PipeWire stream state changed to: {}\n", .{state});
    }

    fn streamProcess(data: ?*anyopaque) callconv(.c) void {
        _ = data;
        // TODO: Implement proper audio processing callback
        // For now, this is a placeholder that will be called from PipeWire's audio thread
        // We need to:
        // 1. Get the stream buffer from PipeWire
        // 2. Call the user's callback with the buffer data
        // 3. Mark buffer as processed
    }
};

pub fn enumerateDevices(allocator: std.mem.Allocator) ![]AudioDevice {
    var backend = PipeWireBackend.init(allocator) catch {
        // Fallback to basic detection
        return enumerateDevicesBasic(allocator);
    };
    defer backend.deinit();

    var devices = try std.ArrayList(AudioDevice).initCapacity(allocator, 4);
    defer devices.deinit(allocator);

    // Add default auto-detect device
    try devices.append(allocator, AudioDevice{
        .id = try allocator.dupe(u8, "auto"),
        .name = try allocator.dupe(u8, "Auto-detect (PipeWire)"),
        .is_default = true,
        .input_channels = 2,
        .output_channels = 2,
    });

    // TODO: Implement proper device enumeration via registry
    // For now, add some common devices
    try devices.append(allocator, AudioDevice{
        .id = try allocator.dupe(u8, "alsa_output.default"),
        .name = try allocator.dupe(u8, "Default Audio Output"),
        .is_default = false,
        .input_channels = 0,
        .output_channels = 2,
    });

    try devices.append(allocator, AudioDevice{
        .id = try allocator.dupe(u8, "alsa_input.default"),
        .name = try allocator.dupe(u8, "Default Audio Input"),
        .is_default = false,
        .input_channels = 2,
        .output_channels = 0,
    });

    return try devices.toOwnedSlice(allocator);
}

fn enumerateDevicesBasic(allocator: std.mem.Allocator) ![]AudioDevice {
    var devices = try std.ArrayList(AudioDevice).initCapacity(allocator, 1);

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
            .name = "PipeWire (Unavailable)",
            .is_default = true,
            .input_channels = 2,
            .output_channels = 2,
        });
    }

    return try devices.toOwnedSlice(allocator);
}

fn checkPipeWireAvailable() bool {
    if (std.process.getEnvVarOwned(std.heap.page_allocator, "PIPEWIRE_RUNTIME_DIR")) |_| {
        return true;
    } else |_| {}

    // Check for default socket location
    std.fs.accessAbsolute("/run/user/1000/pipewire-0", .{}) catch return false;
    return true;
}
