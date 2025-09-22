# beatz Documentation

Welcome to the official documentation for **beatz**, a cross-platform audio I/O library for Zig.

## Overview

beatz provides low-level audio device abstraction and real-time streaming capabilities, designed as the foundation for audio applications in Zig. It focuses specifically on device I/O and streaming, leaving higher-level processing to companion libraries.

## Quick Links

- [Getting Started](getting-started.md) - Installation and basic usage
- [API Reference](api.md) - Complete API documentation
- [Architecture](architecture.md) - Design principles and ecosystem
- [Contributing](contributing.md) - Development guidelines

## Features

- **Device Enumeration**: Discover and manage audio devices across platforms
- **Real-time Streaming**: Low-latency audio input/output with callbacks
- **Cross-platform**: PipeWire (Linux), WASAPI (Windows), CoreAudio (macOS)
- **Format Support**: Basic PCM/WAV with zcodec integration for advanced formats
- **Fallback Support**: Graceful degradation when preferred backends unavailable

## Status

beatz is in active development. Current focus areas:

- ✅ Basic device enumeration (PipeWire detection)
- ✅ WAV file loading
- 🔄 Real-time streaming implementation
- 🔄 Cross-platform backend completion
- 🔄 API stabilization

## License

MIT License - see [LICENSE](../LICENSE) for details.