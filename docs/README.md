# beatz Documentation

Welcome to the beatz audio library documentation! This documentation covers everything you need to get started with beatz, from basic usage to advanced features.

## Table of Contents

### Getting Started
- [Installation](guides/installation.md)
- [Quick Start](guides/quickstart.md)
- [Basic Audio Playback](guides/basic-playback.md)

### API Documentation
- [Core Types](api/core-types.md)
- [AudioContext](api/audiocontext.md)
- [AudioDevice](api/audiodevice.md)
- [AudioStream](api/audiostream.md)
- [Format Conversion](api/format-conversion.md)
- [Sample Rate Conversion](api/sample-rate-conversion.md)
- [Channel Mapping](api/channel-mapping.md)

### Guides
- [Device Management](guides/device-management.md)
- [Audio Recording](guides/audio-recording.md)
- [Real-time Audio Processing](guides/realtime-processing.md)
- [Cross-platform Development](guides/cross-platform.md)
- [Performance Optimization](guides/performance.md)
- [Error Handling](guides/error-handling.md)

### Examples
- [WAV Player](examples/wav-player.md)
- [Audio Recorder](examples/audio-recorder.md)
- [Device Monitor](examples/device-monitor.md)
- [Real-time Effects](examples/realtime-effects.md)

### Backend Documentation
- [PipeWire Backend](api/pipewire-backend.md)
- [ALSA Backend](api/alsa-backend.md)
- [Backend Selection](guides/backend-selection.md)

### Build System
- [Build Options](guides/build-options.md)
- [Performance Flags](guides/performance-flags.md)
- [Footprint Optimization](guides/footprint-optimization.md)

## Library Overview

beatz is a cross-platform audio I/O library for Zig that provides:

- **Device Abstraction**: Unified interface across different audio systems
- **Real-time Streaming**: Low-latency audio input/output with callback-based processing
- **Format Support**: Comprehensive audio format conversion and sample rate conversion
- **Backend Support**: PipeWire, ALSA, with more platforms coming
- **Professional Features**: Device hotplug detection, mixer integration, exclusive mode

## Key Features

### ✅ MVP Features (v0.1.0)
- ✅ Project structure and build system
- ✅ Basic AudioContext initialization
- ✅ Linux PipeWire backend implementation
- ✅ ALSA fallback backend
- ✅ Basic WAV file loading
- ✅ Example applications

### ✅ Alpha Features (v0.2.0)
- ✅ Full PipeWire backend with device hotplug detection
- ✅ Complete ALSA backend with mixer integration
- ✅ Lock-free ring buffer implementation
- ✅ Device capability detection
- ✅ Comprehensive error handling
- ✅ Sample rate conversion
- ✅ Channel mapping and mixing
- ✅ Format conversion
- ✅ Unit tests and example applications

## Quick Example

```zig
const std = @import("std");
const beatz = @import("beatz");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const config = beatz.AudioConfig{
        .sample_rate = 44100,
        .channels = 2,
        .buffer_size = 1024,
    };

    var ctx = try beatz.AudioContext.init(gpa.allocator(), config);
    defer ctx.deinit();

    // Load and play audio file
    var buffer = try beatz.AudioProcessor.loadFile(gpa.allocator(), "audio.wav");
    defer buffer.deinit();

    // Create and start audio stream
    var stream = try ctx.createStream(audioCallback);
    defer stream.deinit();

    try stream.start();
    // ... audio playback happens here
}
```

## Building and Installation

### Prerequisites
- Zig 0.16.0 or later
- Linux: PipeWire development headers, ALSA development headers
- pkg-config

### Quick Build
```bash
# Clone the repository
git clone https://github.com/user/beatz.git
cd beatz

# Build the library
zig build

# Run tests
zig build test

# Build examples
zig build wav-player
zig build audio-recorder
zig build device-monitor
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](../CONTRIBUTING.md) for details on:
- Code style and conventions
- Testing requirements
- Pull request process
- Development setup

## License

beatz is released under the MIT License. See [LICENSE](../LICENSE) for details.