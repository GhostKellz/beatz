# beatz

A cross-platform audio I/O and processing library for Zig, designed to replace C libraries like PortAudio, ALSA, PulseAudio, and JACK.

## Features

- **Cross-platform audio backends**: WASAPI (Windows), CoreAudio (macOS), ALSA/PulseAudio (Linux)
- **Audio formats**: PCM, MP3, OGG, FLAC, AAC, WAV
- **Real-time processing**: Low-latency audio streams, effects chains
- **Device management**: Enumeration, capability detection, hotplug support
- **Synthesis**: Basic oscillators, filters, envelopes for procedural audio
- **MIDI support**: I/O, sequencing, virtual instruments

## Getting Started
# 
```bash
 zig fetch --save https://github.com/ghostkellz/beatz/archive/refs/heads/main.tar.gz

```
--- 
build files
```zig
const beatz = @import("beatz");

var config = beatz.AudioConfig{
    .sample_rate = 44100,
    .channels = 2,
    .buffer_size = 512,
};

var ctx = try beatz.AudioContext.init(allocator, config);
defer ctx.deinit();

const devices = ctx.enumerateDevices();
// Use devices...
```

## Building

```bash
zig build
zig build run
zig build test
```
