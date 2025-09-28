# Build Options and Modular Configuration

beatz supports modular build configuration to optimize for different use cases, from minimal footprint embedded applications to high-performance desktop applications.

## Build Flags

### Performance Optimization Flags

#### `-Dbeatz_mode=performance`
Optimizes for maximum performance at the cost of binary size:
- Enables SIMD optimizations for format conversion
- Uses specialized ring buffer implementations
- Enables branch prediction hints
- Disables bounds checking in audio thread
- Uses aggressive compiler optimizations

#### `-Dbeatz_mode=balanced`
Balanced performance and size (default):
- Standard optimizations enabled
- Basic SIMD support where beneficial
- Reasonable bounds checking
- Good for most applications

#### `-Dbeatz_mode=size`
Optimizes for minimal binary footprint:
- Disables SIMD optimizations
- Uses generic implementations
- Enables size optimizations
- Minimal error context information

### Backend Selection Flags

#### `-Dbeatz_backends=pipewire,alsa`
Select which backends to include (comma-separated):
- `pipewire`: Include PipeWire backend (**always enabled on Linux by default**)
- `alsa`: Include ALSA backend
- `dummy`: Include dummy backend (always available)
- `no-pipewire`: Explicitly disable PipeWire on Linux

**Note**: On Linux, PipeWire is automatically enabled unless explicitly disabled with `no-pipewire`.

Examples:
```bash
# Default - PipeWire + ALSA on Linux
zig build

# ALSA only (disable PipeWire)
zig build -Dbeatz_backends=no-pipewire,alsa

# PipeWire only (disable ALSA)
zig build -Dbeatz_backends=pipewire

# Both backends explicitly (same as default)
zig build -Dbeatz_backends=pipewire,alsa
```

### Feature Flags

#### `-Dbeatz_features=core,mixer,hotplug,conversion`
Enable/disable specific features (comma-separated):
- `core`: Basic audio I/O (always enabled)
- `mixer`: ALSA mixer integration
- `hotplug`: Device hotplug detection
- `conversion`: Format/sample rate conversion
- `effects`: Basic audio effects (planned)

Examples:
```bash
# Minimal build - core only
zig build -Dbeatz_features=core

# Full-featured build
zig build -Dbeatz_features=core,mixer,hotplug,conversion

# Recording-focused build
zig build -Dbeatz_features=core,hotplug
```

### Buffer Configuration

#### `-Dbeatz_buffer_sizes=64,128,256,512,1024,2048,4096`
Compile-time supported buffer sizes. Smaller list = smaller binary:
```bash
# Low-latency focused
zig build -Dbeatz_buffer_sizes=64,128,256

# General purpose (default)
zig build -Dbeatz_buffer_sizes=64,128,256,512,1024,2048,4096

# High-latency tolerant
zig build -Dbeatz_buffer_sizes=1024,2048,4096
```

#### `-Dbeatz_sample_rates=44100,48000,96000`
Supported sample rates for optimization:
```bash
# CD quality only
zig build -Dbeatz_sample_rates=44100

# Professional audio
zig build -Dbeatz_sample_rates=44100,48000,96000,192000

# Embedded/IoT
zig build -Dbeatz_sample_rates=16000,22050,44100
```

## Configuration Examples

### Embedded/IoT Device
Minimal footprint, basic functionality:
```bash
zig build -Doptimize=ReleaseFast \
          -Dbeatz_mode=size \
          -Dbeatz_backends=no-pipewire,alsa \
          -Dbeatz_features=core \
          -Dbeatz_buffer_sizes=1024,2048 \
          -Dbeatz_sample_rates=16000,44100
```

### Desktop Audio Application
Full features, balanced performance:
```bash
zig build -Doptimize=ReleaseFast \
          -Dbeatz_mode=balanced \
          -Dbeatz_backends=pipewire,alsa \
          -Dbeatz_features=core,mixer,hotplug,conversion
```

### Real-time Audio Processing
Maximum performance, low latency (PipeWire only):
```bash
zig build -Doptimize=ReleaseFast \
          -Dbeatz_mode=performance \
          -Dbeatz_backends=pipewire,no-alsa \
          -Dbeatz_features=core,hotplug \
          -Dbeatz_buffer_sizes=64,128,256 \
          -Dbeatz_sample_rates=44100,48000,96000
```

### Audio Recorder/Player
Recording focused with format support:
```bash
zig build -Doptimize=ReleaseFast \
          -Dbeatz_mode=balanced \
          -Dbeatz_backends=pipewire,alsa \
          -Dbeatz_features=core,conversion,hotplug
```

## Conditional Compilation

beatz uses conditional compilation based on build flags:

```zig
// In your application
const beatz = @import("beatz");

pub fn main() !void {
    // Check available features at compile time
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
}
```

## Performance Impact

| Configuration | Binary Size | Memory Usage | CPU Usage | Latency |
|--------------|-------------|--------------|-----------|---------|
| Embedded     | ~50KB       | ~1MB         | Low       | ~20ms   |
| Balanced     | ~150KB      | ~5MB         | Medium    | ~10ms   |
| Performance  | ~300KB      | ~10MB        | High      | ~5ms    |
| Full         | ~500KB      | ~15MB        | Medium    | ~10ms   |

*Note: Values are approximate and depend on specific usage patterns*

## Validation

Build flags are validated at compile time:
- Invalid backend combinations will fail compilation
- Unsupported feature combinations are rejected
- Buffer size constraints are enforced
- Sample rate limits are checked

## Future Enhancements

Planned modular features:
- **Codec Support**: Optional MP3, FLAC, OGG support
- **Effects Processing**: Optional reverb, EQ, filters
- **Network Audio**: Optional network streaming
- **Platform Backends**: Windows WASAPI, macOS CoreAudio
- **GPU Processing**: Optional GPU-accelerated effects

This modular approach ensures beatz can scale from tiny embedded devices to high-end audio workstations while maintaining a consistent API.