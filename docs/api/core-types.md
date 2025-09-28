# Core Types

This document describes the fundamental types used throughout the beatz audio library.

## AudioConfig

Configuration structure for audio contexts and streams.

```zig
pub const AudioConfig = struct {
    sample_rate: u32 = 44100,      // Sample rate in Hz
    channels: u16 = 2,             // Number of audio channels
    buffer_size: usize = 1024,     // Buffer size in frames
    mode: AudioMode = .shared,     // Audio mode (shared/exclusive)
};
```

### Fields

- **sample_rate**: Sample rate in Hz. Common values: 16000, 22050, 44100, 48000, 96000, 192000
- **channels**: Number of audio channels. 1 = mono, 2 = stereo, 6 = 5.1 surround
- **buffer_size**: Buffer size in frames (not bytes). Smaller = lower latency, higher CPU usage
- **mode**: Audio sharing mode (see AudioMode)

### Example

```zig
const config = beatz.AudioConfig{
    .sample_rate = 48000,
    .channels = 2,
    .buffer_size = 512,  // ~10ms latency at 48kHz
    .mode = .shared,
};
```

## AudioMode

Audio device sharing mode.

```zig
pub const AudioMode = enum {
    shared,     // Share device with other applications
    exclusive,  // Exclusive device access (lower latency)
};
```

### Modes

- **shared**: Device is shared with other applications. Most compatible.
- **exclusive**: Exclusive device access. Lower latency but may fail if device is in use.

## AudioFormat

Audio sample format specification.

```zig
pub const AudioFormat = enum {
    u8,      // 8-bit unsigned integer
    s16_le,  // 16-bit signed integer, little endian
    s24_le,  // 24-bit signed integer, little endian
    s32_le,  // 32-bit signed integer, little endian
    f32_le,  // 32-bit float, little endian
    f64_le,  // 64-bit float, little endian
};
```

### Methods

```zig
// Get sample size in bytes
pub fn getBytesPerSample(self: AudioFormat) u8

// Check if format is floating point
pub fn isFloatingPoint(self: AudioFormat) bool
```

### Example

```zig
const format = beatz.AudioFormat.f32_le;
const bytes_per_sample = format.getBytesPerSample(); // 4
const is_float = format.isFloatingPoint();           // true
```

## AudioDevice

Audio device information structure.

```zig
pub const AudioDevice = struct {
    id: []const u8,                           // Unique device identifier
    name: []const u8,                         // Human-readable device name
    is_default: bool = false,                 // Whether this is the default device
    input_channels: u16 = 0,                  // Number of input channels
    output_channels: u16 = 0,                 // Number of output channels
    capabilities: ?DeviceCapabilities = null, // Device capabilities (optional)
};
```

### Methods

```zig
// Check if device supports a configuration
pub fn supportsConfig(self: AudioDevice, config: AudioConfig) bool

// Clean up allocated device data
pub fn deinit(self: *AudioDevice, allocator: std.mem.Allocator) void
```

## DeviceCapabilities

Detailed device capability information.

```zig
pub const DeviceCapabilities = struct {
    supported_sample_rates: []const u32,     // Supported sample rates
    supported_formats: []const AudioFormat,  // Supported audio formats
    min_channels: u16,                        // Minimum channel count
    max_channels: u16,                        // Maximum channel count
    min_buffer_size: usize,                   // Minimum buffer size
    max_buffer_size: usize,                   // Maximum buffer size
    min_latency_us: u32,                      // Minimum latency in microseconds
    max_latency_us: u32,                      // Maximum latency in microseconds
};
```

### Methods

```zig
// Check if sample rate is supported
pub fn supportsSampleRate(self: DeviceCapabilities, rate: u32) bool

// Check if format is supported
pub fn supportsFormat(self: DeviceCapabilities, format: AudioFormat) bool

// Check if channel count is supported
pub fn supportsChannelCount(self: DeviceCapabilities, channels: u16) bool

// Clean up capabilities data
pub fn deinit(self: *DeviceCapabilities, allocator: std.mem.Allocator) void
```

## AudioBuffer

Audio data buffer structure.

```zig
pub const AudioBuffer = struct {
    data: []f32,                    // Audio sample data (interleaved)
    sample_rate: u32,               // Sample rate of the audio data
    channels: u16,                  // Number of channels
    allocator: std.mem.Allocator,   // Allocator used for data
};
```

### Methods

```zig
// Clean up buffer data
pub fn deinit(self: *AudioBuffer) void

// Get duration in seconds
pub fn getDuration(self: AudioBuffer) f64

// Get frame count
pub fn getFrameCount(self: AudioBuffer) usize
```

### Example

```zig
var buffer = try beatz.AudioProcessor.loadFile(allocator, "audio.wav");
defer buffer.deinit();

const duration = buffer.getDuration();
const frames = buffer.getFrameCount();
```

## AudioCallback

Function pointer type for audio processing callbacks.

```zig
pub const AudioCallback = *const fn(
    input: ?[]const f32,    // Input audio data (nullable)
    output: []f32,          // Output audio buffer
    frame_count: usize      // Number of frames to process
) void;
```

### Parameters

- **input**: Input audio data (null for output-only streams)
- **output**: Output buffer to fill with audio data
- **frame_count**: Number of audio frames to process

### Example

```zig
fn audioCallback(input: ?[]const f32, output: []f32, frame_count: usize) void {
    // Generate silence
    for (0..frame_count * 2) |i| {  // 2 channels
        output[i] = 0.0;
    }
}
```

## Error Types

### AudioError

Main error enumeration for beatz operations.

```zig
pub const AudioError = error{
    // Initialization errors
    BackendInitFailed,
    DeviceNotFound,
    ConfigurationNotSupported,

    // Runtime errors
    StreamCreateFailed,
    StreamStartFailed,
    BufferUnderrun,
    BufferOverrun,

    // Format errors
    UnsupportedFormat,
    UnsupportedSampleRate,
    UnsupportedChannelCount,

    // System errors
    PermissionDenied,
    DeviceBusy,
    ResourceExhausted,

    // File I/O errors
    FileNotFound,
    InvalidFileFormat,
    CorruptedData,
};
```

### ErrorContext

Detailed error context information.

```zig
pub const ErrorContext = struct {
    message: []const u8,
    backend_name: ?[]const u8 = null,
    device_id: ?[]const u8 = null,
    error_code: ?i32 = null,

    // Methods for building error context
    pub fn init(message: []const u8) ErrorContext
    pub fn withBackend(self: ErrorContext, backend: []const u8) ErrorContext
    pub fn withDevice(self: ErrorContext, device: []const u8) ErrorContext
    pub fn withErrorCode(self: ErrorContext, code: i32) ErrorContext
    pub fn format(self: ErrorContext, allocator: std.mem.Allocator) ![]u8
};
```

### AudioResult

Result type for operations that can fail with detailed context.

```zig
pub fn AudioResult(comptime T: type) type {
    return union(enum) {
        success: T,
        failure: struct {
            err: AudioError,
            context: ErrorContext,
        },

        pub fn isSuccess(self: @This()) bool
        pub fn isFailure(self: @This()) bool
        pub fn unwrap(self: @This()) AudioError!T
    };
}
```

## Build Configuration

### Features

Runtime feature detection based on build configuration.

```zig
pub const features = struct {
    pub const pipewire_support: bool;    // PipeWire backend available
    pub const alsa_support: bool;        // ALSA backend available
    pub const mixer_support: bool;       // Mixer functionality available
    pub const hotplug_support: bool;     // Device hotplug detection available
    pub const conversion_support: bool;  // Format/rate conversion available
    pub const performance_mode: enum { performance, balanced, size };
};
```

### Example

```zig
if (beatz.features.mixer_support) {
    // Use mixer functionality
    if (ctx.getMixer()) |mixer| {
        try mixer.setVolume(0.8);
    }
}

if (beatz.features.conversion_support) {
    // Use format conversion
    var converter = beatz.SampleRateConverter.init(44100, 48000);
    // ...
}
```