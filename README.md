# FFmpegCore

Modern Ruby wrapper for FFmpeg with clean API and proper error handling.

[![Gem Version](https://badge.fury.io/rb/ffmpeg_core.svg)](https://badge.fury.io/rb/ffmpeg_core)
[![Build Status](https://github.com/alec-c4/ffmpeg_core/actions/workflows/main.yml/badge.svg)](https://github.com/alec-c4/ffmpeg_core/actions)

## Features

- Modern Ruby 3+ conventions
- Zero runtime dependencies
- **Real-time progress reporting**
- **Support for video/audio filters and quality presets**
- **Hardware Acceleration (NVENC, VAAPI, QSV, Vulkan AV1, D3D12)**
- **Remote input support (HTTP/HTTPS/RTMP/RTSP)**
- **Rich metadata: chapters, subtitles, EXIF, audio properties**
- **Video operations: cut, audio extraction, batch screenshots**
- **Multi-input composition: overlay, concatenation, side-by-side**
- Proper error handling with detailed context
- Thread-safe configuration
- Simple, intuitive API

## FFmpeg Version Requirements

| Feature | Minimum FFmpeg version |
|---|---|
| Core transcoding, probing | Any recent version |
| AV1 hardware encoding (Vulkan) | 8.0+ |
| EXIF metadata parsing | 8.1+ |
| D3D12 hardware acceleration | 8.1+ |
| Chapter metadata (`chapters`) | Any (via `-show_chapters`) |

## Requirements

- Ruby 3.2+
- FFmpeg installed (`brew install ffmpeg` on macOS)

## Installation

Add to your Gemfile:

```ruby
gem "ffmpeg_core"
```

Then run:

```bash
bundle install
```

## Usage

### Basic Usage

```ruby
require "ffmpeg_core"

# Load a video file or remote URL
movie = FFmpegCore::Movie.new("input.mp4")
# movie = FFmpegCore::Movie.new("http://example.com/video.mp4")

# Basic metadata
movie.duration      # => 120.5 (seconds)
movie.resolution    # => "1920x1080" (automatically swapped if rotated)
movie.width         # => 1920
movie.height        # => 1080
movie.video_codec   # => "h264"
movie.audio_codec   # => "aac"
movie.frame_rate    # => 29.97
movie.bitrate       # => 5000 (kb/s)
movie.valid?        # => true
movie.has_video?    # => true
movie.has_audio?    # => true

# Video stream details
movie.probe.rotation      # => 90 (degrees)
movie.probe.aspect_ratio  # => "16:9"
movie.probe.video_profile # => "High"
movie.probe.video_level   # => 41
movie.probe.pixel_format  # => "yuv420p"

# Audio stream details
movie.probe.audio_sample_rate    # => 48000
movie.probe.audio_channels       # => 2
movie.probe.audio_channel_layout # => "stereo"
movie.probe.audio_streams        # => [{ "codec_type" => "audio", ... }, ...]

# Subtitles and chapters
movie.probe.subtitle_streams # => [{ "codec_name" => "subrip", ... }]
movie.probe.chapters         # => [{ "tags" => { "title" => "Intro" }, ... }]

# File-level tags and EXIF (FFmpeg 8.1+ for full EXIF support)
movie.probe.tags  # => { "title" => "My Video", "artist" => "Author" }
movie.probe.exif  # => { "creation_time" => "2024-06-15T14:30:00Z", ... }

# Container format
movie.probe.format_name # => "mov,mp4,m4a,3gp,3g2,mj2"
```

### Transcoding

```ruby
movie = FFmpegCore::Movie.new("input.mp4")

# Basic transcoding with progress
movie.transcode("output.mp4", video_codec: "libx264") do |progress|
  puts "Progress: #{(progress * 100).round(2)}%"
end

# Advanced options (Filters & Quality)
movie.transcode("output.mp4", {
  video_codec: "libx264",
  audio_codec: "aac",
  video_bitrate: "1000k",
  audio_bitrate: "128k",
  resolution: "1280x720",
  crop: { width: 500, height: 500, x: 10, y: 10 }, # Crop video
  video_filter: "scale=1280:-1,transpose=1", # Resize and rotate
  audio_filter: "volume=0.5",                # Reduce volume
  preset: "slow",      # ffmpeg preset (ultrafast, fast, medium, slow, etc.)
  crf: 23              # Constant Rate Factor (0-51)
})
```

### Complex Filter Graphs & Stream Mapping

Use structured APIs for `-filter_complex` and `-map` to build complex pipelines without raw string hacks.

```ruby
movie.transcode("out.mp4", {
  filter_graph: [
    "[0:v]crop=320:240:0:0[c]",
    "[c]scale=640:480[outv]"
  ],
  maps: ["[outv]", "0:a"]
})
```

### Multi-Input Composition

Use `FFmpegCore::Compositor` when you need multiple input files in a single FFmpeg command — overlay, concatenation, side-by-side, and any other `-filter_complex` operation.

```ruby
# Overlay (picture-in-picture): place overlay.mp4 on top of background.mp4
FFmpegCore::Compositor.new(
  ["background.mp4", "overlay.mp4"],
  "output.mp4",
  filter_complex: "[0:v][1:v]overlay=10:10[v]",
  maps: ["[v]", "0:a"]
).run

# Concatenate two clips sequentially
FFmpegCore::Compositor.new(
  ["part1.mp4", "part2.mp4"],
  "output.mp4",
  filter_complex: "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[v][a]",
  maps: ["[v]", "[a]"]
).run

# Side-by-side (horizontal stack)
FFmpegCore::Compositor.new(
  ["left.mp4", "right.mp4"],
  "output.mp4",
  filter_complex: "[0:v][1:v]hstack[v]",
  maps: ["[v]", "0:a"]
).run

# With progress reporting (requires :duration)
FFmpegCore::Compositor.new(
  ["a.mp4", "b.mp4"],
  "output.mp4",
  filter_complex: "[0:v][1:v]overlay[v]",
  maps: ["[v]", "0:a"],
  duration: 120.0
).run do |progress|
  puts "#{(progress * 100).round}%"
end
```

> **Note:** Stream indices (`[0:v]`, `[1:v]`, etc.) correspond to the position of each file in the input array.

### Cutting / Trimming

Lossless trim using stream copy — no re-encoding, nearly instant:

```ruby
# Trim by start time + duration
movie.cut("clip.mp4", start_time: 30, duration: 60)

# Trim by start and end time
movie.cut("clip.mp4", start_time: 30, end_time: 90)
```

> **Note:** `-c copy` seeks to the nearest keyframe. For frame-accurate trimming, use `transcode` with `custom: ["-ss", "30", "-to", "90"]`.

### Audio Extraction

```ruby
# Extract audio with automatic codec detection from file extension
movie.extract_audio("audio.aac")

# Specify codec explicitly
movie.extract_audio("audio.mp3", codec: "libmp3lame")
movie.extract_audio("audio.opus", codec: "libopus")
```

### Multiple Screenshots

```ruby
# Extract 5 screenshots distributed evenly across the video
paths = movie.screenshots("thumbs/", count: 5)
# => ["thumbs/screenshot_001.jpg", ..., "thumbs/screenshot_005.jpg"]
```

### Hardware Acceleration

Opt-in to hardware-accelerated encoding with automatic encoder detection and graceful fallback.

```ruby
# H.264 / HEVC — classic accelerators
movie.transcode("out.mp4", hwaccel: :nvenc)           # NVIDIA CUDA
movie.transcode("out.mp4", hwaccel: :vaapi)           # Linux VAAPI
movie.transcode("out.mp4", hwaccel: :qsv)             # Intel Quick Sync

# AV1 — requires FFmpeg 8.0+
movie.transcode("out.mp4", video_codec: "libaom-av1", hwaccel: :nvenc)   # NVIDIA
movie.transcode("out.mp4", video_codec: "libaom-av1", hwaccel: :vaapi)   # VAAPI
movie.transcode("out.mp4", video_codec: "libaom-av1", hwaccel: :vulkan)  # Vulkan compute

# D3D12 — Windows only, requires FFmpeg 8.1+
movie.transcode("out.mp4", hwaccel: :d3d12)
```

All accelerators gracefully fall back to software encoding if the hardware encoder is not available.

### Using Filters

FFmpegCore supports raw FFmpeg filter strings for both video (`video_filter` or `-vf`) and audio (`audio_filter` or `-af`).

**Common Video Filters:**

```ruby
movie.transcode("output.mp4", {
  # Scale to width 1280, keep aspect ratio
  video_filter: "scale=1280:-1",

  # Crop 100x100 starting at position (10,10)
  video_filter: "crop=100:100:10:10",

  # Rotate 90 degrees clockwise
  video_filter: "transpose=1",

  # Chain multiple filters (Scale then Rotate)
  video_filter: "scale=1280:-1,transpose=1"
})
```

**Common Audio Filters:**

```ruby
movie.transcode("output.mp4", {
  # Increase volume by 50%
  audio_filter: "volume=1.5",

  # Fade in first 5 seconds
  audio_filter: "afade=t=in:ss=0:d=5"
})
```

### Screenshots

```ruby
movie = FFmpegCore::Movie.new("input.mp4")

# Extract screenshot at specific time
movie.screenshot("thumbnail.jpg", seek_time: 5)

# With resolution and quality
movie.screenshot("thumbnail.jpg", {
  seek_time: 10,
  resolution: "640x360",
  quality: 2  # 2-31, lower is better
})
```

### Configuration

```ruby
FFmpegCore.configure do |config|
  config.ffmpeg_binary = "/usr/local/bin/ffmpeg"
  config.ffprobe_binary = "/usr/local/bin/ffprobe"
  config.timeout = 60
end
```

## Error Handling

FFmpegCore provides specific error classes for different failure scenarios. All execution errors (transcoding, probing, screenshots) inherit from `FFmpegCore::ExecutionError`, which provides access to the command, exit status, and stderr output.

```ruby
begin
  movie = FFmpegCore::Movie.new("input.mp4")
  movie.transcode("output.mp4", video_codec: "libx264")
rescue FFmpegCore::InvalidInputError => e
  # File doesn't exist or is not readable
  puts "Input error: #{e.message}"
rescue FFmpegCore::ExecutionError => e
  # Covers TranscodingError, ProbeError, and ScreenshotError
  puts "Execution failed: #{e.message}"
  puts "Command: #{e.command}"
  puts "Exit status: #{e.exit_status}"
  puts "Stderr: #{e.stderr}"
rescue FFmpegCore::BinaryNotFoundError => e
  # FFmpeg not installed
  puts "FFmpeg not found: #{e.message}"
end
```

### Error Classes

| Error                             | Description                            | Parent |
| --------------------------------- | -------------------------------------- | ------ |
| `FFmpegCore::Error`               | Base error class                       | StandardError |
| `FFmpegCore::BinaryNotFoundError` | FFmpeg/FFprobe not found               | Error |
| `FFmpegCore::InvalidInputError`   | Input file doesn't exist or unreadable | Error |
| `FFmpegCore::OutputError`         | Output file cannot be written          | Error |
| `FFmpegCore::ExecutionError`      | Base for command execution errors      | Error |
| `FFmpegCore::ProbeError`          | Failed to extract metadata             | ExecutionError |
| `FFmpegCore::TranscodingError`    | FFmpeg transcoding failed              | ExecutionError |
| `FFmpegCore::ScreenshotError`     | Screenshot extraction failed           | ExecutionError |

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop
```

## License

MIT License. See [LICENSE.txt](LICENSE.txt) for details.
