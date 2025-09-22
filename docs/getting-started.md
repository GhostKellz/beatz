# Getting Started

This guide will help you get beatz up and running in your Zig project.

## Installation

### Add to Your Project

```bash
zig fetch --save https://github.com/ghostkellz/beatz/archive/refs/heads/main.tar.gz
```

### Configure build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add beatz dependency
    const beatz_dep = b.dependency("beatz", .{
        .target = target,
        .optimize = optimize,
    });

    // Create your executable
    const exe = b.addExecutable(.{
        .name = "my_audio_app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link beatz module
    exe.root_module.addImport("beatz", beatz_dep.module("beatz"));

    // On Linux, link PipeWire (optional but recommended)
    if (target.result.os.tag == .linux) {
        exe.linkSystemLibrary("pipewire-0.3");
        exe.linkLibC();
    }

    b.installArtifact(exe);
}
```

## Basic Usage

### Initialize Audio Context

```zig
const std = @import("std");
const beatz = @import("beatz");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Configure audio settings
    const config = beatz.AudioConfig{
        .sample_rate = 44100,
        .channels = 2,
        .buffer_size = 512,
    };

    // Initialize audio context
    var ctx = try beatz.AudioContext.init(allocator, config);
    defer ctx.deinit();

    std.debug.print("Audio context initialized!\n", .{});
}
```

### Enumerate Devices

```zig
// Get available audio devices
const devices = ctx.enumerateDevices();
std.debug.print("Found {} audio devices:\n", .{devices.len});

for (devices) |device| {
    std.debug.print("  - {s} (id: {s})\n", .{device.name, device.id});
    std.debug.print("    Input channels: {}, Output channels: {}\n",
        .{device.input_channels, device.output_channels});
}
```

### Load Audio Files

```zig
// Load a WAV file
var buffer = try beatz.AudioProcessor.loadFile(allocator, "audio.wav");
defer buffer.deinit();

std.debug.print("Loaded audio: {} samples, {} channels, {}Hz\n",
    .{buffer.data.len / buffer.channels, buffer.channels, buffer.sample_rate});
```

## Next Steps

- **Real-time Streaming**: Implement `AudioContext.createStream()` for live audio I/O
- **Format Support**: Use zcodec for MP3, FLAC, and other compressed formats
- **Audio Processing**: Apply effects and synthesis with zdsp

## Troubleshooting

### Build Errors on Linux

If you get PipeWire-related errors:

1. Install PipeWire development headers:
   ```bash
   # Ubuntu/Debian
   sudo apt install libpipewire-0.3-dev

   # Fedora
   sudo dnf install pipewire-devel
   ```

2. Or disable PipeWire linking in build.zig for basic functionality

### No Audio Devices Found

- On Linux: Ensure PipeWire is running (`systemctl --user status pipewire`)
- Check that your user has audio permissions
- beatz will fall back to dummy devices if no real devices are available

## Examples

See the `src/main.zig` file in the beatz repository for a complete working example.