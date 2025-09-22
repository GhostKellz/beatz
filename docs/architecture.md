# Architecture

This document explains the design principles and architecture of beatz.

## Design Philosophy

beatz follows the Unix philosophy: **do one thing and do it well**. It focuses exclusively on audio device I/O and real-time streaming, providing a solid foundation for higher-level audio processing.

## Ecosystem Integration

beatz is part of a larger audio ecosystem in Zig:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│      beatz      │    │     zcodec      │    │      zdsp       │
│                 │    │                 │    │                 │
│  Device I/O     │◄──►│ Format Encoding │◄──►│   DSP/Effects   │
│  Streaming      │    │   Decoding      │    │   Synthesis     │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### beatz (This Library)
- **Scope**: Low-level device abstraction and real-time streaming
- **Responsibilities**:
  - Device enumeration and management
  - Audio stream creation and management
  - Platform-specific backend implementation
  - Basic format conversion (sample rate, channels)
  - Buffer management

### zcodec (Companion)
- **Scope**: Audio format encoding/decoding
- **Responsibilities**:
  - MP3, FLAC, AAC, OGG encoding/decoding
  - Metadata handling (ID3, Vorbis comments)
  - Progressive decoding and seeking
  - High-quality encoding

### zdsp (Companion)
- **Scope**: Digital signal processing
- **Responsibilities**:
  - Audio effects (reverb, delay, EQ, compression)
  - Filters (IIR/FIR, FFT-based)
  - Synthesis (oscillators, noise generation)
  - Real-time convolution

## Core Components

### AudioContext
The central coordinator that manages:
- Device enumeration
- Stream lifecycle
- Platform backend selection
- Resource management

### Platform Backends
Each platform has a dedicated backend:

- **Linux**: PipeWire (primary), ALSA (fallback)
- **Windows**: WASAPI (primary), DirectSound (fallback)
- **macOS**: CoreAudio (primary)

Backends implement the same interface but use platform-specific APIs.

### AudioBuffer
A simple container for audio data with:
- Raw f32 samples
- Metadata (sample rate, channels)
- Memory management

## Threading Model

beatz uses a callback-based model for real-time audio:

```zig
const AudioCallback = fn (input: ?[]const f32, output: []f32, frame_count: usize) void;
```

- Callbacks run in audio thread context
- Must be real-time safe (no allocations, locks)
- Input/output buffers are pre-allocated
- Frame count indicates buffer size in frames

## Error Handling

beatz uses Zig's error union system:

- **Recoverable errors**: Device unavailable, format unsupported
- **Fatal errors**: Out of memory, invalid parameters
- **Platform errors**: Backend-specific failures

## Memory Management

- **Arena allocation**: Audio buffers use dedicated allocators
- **RAII pattern**: Contexts and streams clean up automatically
- **Zero-copy**: Where possible, avoid unnecessary copying
- **Leak prevention**: All resources have explicit cleanup

## Platform Abstraction

The backend system provides:

```zig
// Platform-agnostic interface
pub fn enumerateDevices(allocator: std.mem.Allocator) ![]AudioDevice;
pub fn createStream(config: StreamConfig, callback: AudioCallback) !AudioStream;
```

Each platform implements these with native APIs, ensuring optimal performance and compatibility.

## Future Considerations

### Performance
- Lock-free ring buffers for inter-thread communication
- SIMD optimization for format conversion
- Platform-specific optimizations

### Features
- Hotplug device detection
- Multi-device routing
- Network audio streaming
- MIDI integration

### Compatibility
- Maintain API stability
- Support multiple Zig versions
- Cross-compilation support