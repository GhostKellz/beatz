# API Reference

This document provides a complete reference for the beatz public API.

## Core Types

### AudioConfig

Configuration for audio context initialization.

```zig
pub const AudioConfig = struct {
    sample_rate: u32 = 44100,
    channels: u16 = 2,
    buffer_size: usize = 1024,
};
```

### AudioDevice

Represents an audio device with its capabilities.

```zig
pub const AudioDevice = struct {
    id: []const u8,
    name: []const u8,
    is_default: bool = false,
    input_channels: u16 = 0,
    output_channels: u16 = 0,
};
```

### AudioBuffer

Container for audio data with metadata.

```zig
pub const AudioBuffer = struct {
    data: []f32,
    sample_rate: u32,
    channels: u16,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *AudioBuffer) void;
};
```

### AudioContext

Main interface for audio device management and streaming.

```zig
pub const AudioContext = struct {
    allocator: std.mem.Allocator,
    config: AudioConfig,
    devices: std.ArrayList(AudioDevice),

    pub fn init(allocator: std.mem.Allocator, config: AudioConfig) !AudioContext;
    pub fn deinit(self: *AudioContext) void;
    pub fn createStream(self: *AudioContext, callback: AudioCallback) !AudioStream;
    pub fn enumerateDevices(self: AudioContext) []AudioDevice;
};
```

### AudioStream

Represents an active audio stream (placeholder - not yet implemented).

```zig
pub const AudioStream = struct {
    // TODO: implement stream functionality
};
```

### AudioProcessor

Handles audio file loading and basic processing.

```zig
pub const AudioProcessor = struct {
    pub fn loadFile(allocator: std.mem.Allocator, path: []const u8) !AudioBuffer;
};
```

## Callbacks

### AudioCallback

Function signature for audio stream callbacks.

```zig
pub const AudioCallback = fn (input: ?[]const f32, output: []f32, frame_count: usize) void;
```

## Error Types

beatz uses standard Zig error unions. Common errors include:

- `error.OutOfMemory` - Allocation failures
- `error.InvalidFormat` - Unsupported audio formats
- `error.FileNotFound` - File access errors
- `error.UnsupportedFormat` - Format not supported

## Platform-Specific Notes

### Linux (PipeWire)
- Primary backend: PipeWire with runtime detection
- Fallback: ALSA (planned)
- Requires: `libpipewire-0.3` system library

### Windows (WASAPI)
- Status: Planned
- Requires: Windows SDK

### macOS (CoreAudio)
- Status: Planned
- Requires: CoreAudio framework

## Integration with Companion Libraries

beatz is designed to work with:

- **zcodec**: For advanced audio format support (MP3, FLAC, etc.)
- **zdsp**: For digital signal processing and effects

Example integration:

```zig
// Load audio file (beatz handles WAV, zcodec handles others)
const buffer = try beatz.AudioProcessor.loadFile(allocator, "audio.wav");

// Apply effects (zdsp handles processing)
const processed = try zdsp.applyEffect(buffer, effect);

// Save in different format (zcodec handles encoding)
try zcodec.encodeFile(processed, "output.mp3", .mp3);
```