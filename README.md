<div align="center">
  <img src="assets/beatz.png" alt="beatz logo" width="200"/>
  
  # beatz
  
  **Cross-platform audio I/O library for Zig**
  
  [![Built with Zig](https://img.shields.io/badge/Built%20with-Zig-yellow?style=flat&logo=zig)](https://ziglang.org/)
  [![Zig 0.16.0-dev](https://img.shields.io/badge/Zig-0.16.0--dev-orange?style=flat&logo=zig)](https://ziglang.org/download/)
  [![PipeWire](https://img.shields.io/badge/Audio-PipeWire-blue?style=flat)](https://pipewire.org/)
  [![ALSA](https://img.shields.io/badge/Fallback-ALSA-lightblue?style=flat)](https://www.alsa-project.org/)
  [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
</div>

📚 **[Full Documentation](docs/)** | [API Reference](docs/api.md) | [Getting Started](docs/getting-started.md)

## Vision

**beatz** is a modern, safe, and performant audio I/O library designed to replace legacy C audio libraries (PortAudio, ALSA, PulseAudio, JACK) with a pure Zig implementation. Part of a larger ecosystem:

- **beatz**: Audio device I/O and real-time streaming (this library)
- **zcodec**: Audio format encoding/decoding (MP3, FLAC, etc.)
- **zdsp**: Digital signal processing and effects

## Features

- **🎯 Device I/O Focus**: Pure audio device abstraction and low-latency streaming
- **🌍 Cross-platform**: PipeWire (Linux), WASAPI (Windows), CoreAudio (macOS)
- **⚡ Low-latency**: Sub-10ms audio streams with lock-free ring buffers
- **🔧 Device Management**: Enumeration, capability detection, hotplug support
- **📊 Format Conversion**: Sample rate conversion, channel mapping
- **🔄 Fallback Support**: Graceful degradation (PipeWire → ALSA → dummy)

## Installation

Add beatz to your Zig project:

```bash
zig fetch --save https://github.com/ghostkellz/beatz/archive/refs/heads/main.tar.gz
```

In your `build.zig`:
```zig
const beatz = b.dependency("beatz", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("beatz", beatz.module("beatz"));
```

## Quick Start
```zig
const std = @import("std");
const beatz = @import("beatz");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize audio context
    const config = beatz.AudioConfig{
        .sample_rate = 44100,
        .channels = 2,
        .buffer_size = 512,
    };

    var ctx = try beatz.AudioContext.init(allocator, config);
    defer ctx.deinit();

    // Enumerate available audio devices
    const devices = ctx.enumerateDevices();
    std.debug.print("Found {} audio devices:\n", .{devices.len});
    for (devices) |device| {
        std.debug.print("  - {s} ({})\n", .{ device.name, device.id });
    }

    // TODO: Create audio streams, load files, etc.
}
```

## Architecture

beatz focuses specifically on **audio device I/O and real-time streaming**:

- **Device Abstraction**: Unified API across PipeWire, WASAPI, CoreAudio
- **Stream Management**: Low-latency audio input/output with callbacks
- **Format Handling**: Basic PCM and WAV support (complex codecs via zcodec)
- **Platform Integration**: Native backends with graceful fallbacks

For audio effects, synthesis, and advanced DSP, use the companion **zdsp** library.  
For audio format encoding/decoding, use the companion **zcodec** library.

## Platform Support

| Platform | Primary Backend | Fallback | Status |
|----------|----------------|----------|---------|
| Linux    | PipeWire       | ALSA     | ✅ In Progress |
| Windows  | WASAPI         | DirectSound | 🔄 Planned |
| macOS    | CoreAudio      | -        | 🔄 Planned |

## Development

```bash
# Clone and build
git clone https://github.com/ghostkellz/beatz.git
cd beatz
zig build

# Run example
zig build run

# Run tests
zig build test
```

## Contributing

We welcome contributions! beatz is part of a larger effort to modernize audio infrastructure with Zig.

## License

MIT License - see [LICENSE](LICENSE) for details.
