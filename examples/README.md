# beatz Examples

This directory contains example applications demonstrating how to use the beatz audio library.

## WAV Player Example

A simple WAV file player that demonstrates:

- Loading WAV files using `AudioProcessor.loadFile()`
- Creating audio streams with callbacks
- Real-time audio playback through PipeWire/ALSA

### Building and Running

```bash
# Build the WAV player example
zig build wav-player

# Run with a WAV file
./zig-out/bin/wav_player path/to/your/file.wav
```

### Requirements

- 16-bit PCM WAV files
- Linux with PipeWire or ALSA
- Audio output device

### Example WAV File Creation

You can create a test WAV file using various tools:

```bash
# Using ffmpeg to create a test tone
ffmpeg -f lavfi -i "sine=frequency=440:duration=3" -acodec pcm_s16le test.wav

# Using aplay to record from microphone
arecord -f cd -t wav -d 5 test.wav
```

### Code Structure

The example demonstrates:

1. **Audio Context Creation**: Setting up the audio system
2. **WAV File Loading**: Reading and parsing WAV files
3. **Stream Creation**: Creating audio output streams
4. **Callback-based Playback**: Real-time audio processing
5. **Resource Management**: Proper cleanup of audio resources

This example serves as a foundation for more complex audio applications.