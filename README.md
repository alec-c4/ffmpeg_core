# FFmpegCore

Modern Ruby wrapper for FFmpeg with clean API and proper error handling.

[![Gem Version](https://badge.fury.io/rb/ffmpeg_core.svg)](https://badge.fury.io/rb/ffmpeg_core)
[![Build Status](https://github.com/alec-c4/ffmpeg_core/actions/workflows/main.yml/badge.svg)](https://github.com/alec-c4/ffmpeg_core/actions)

## Features

- Modern Ruby 3+ conventions
- Zero runtime dependencies
- **Real-time progress reporting**
- **Support for video/audio filters and quality presets**
- Proper error handling with detailed context
- Thread-safe configuration
- Simple, intuitive API

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

# Load a video file
movie = FFmpegCore::Movie.new("input.mp4")

# Get metadata
movie.duration      # => 120.5 (seconds)
movie.resolution    # => "1920x1080"
movie.video_codec   # => "h264"
movie.audio_codec   # => "aac"
movie.frame_rate    # => 29.97
movie.bitrate       # => 5000 (kb/s)
movie.rotation      # => 90 (degrees)
movie.aspect_ratio  # => "16:9"
movie.valid?        # => true
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
  resolution: "1280x720",
  video_filter: "scale=1280:-1,transpose=1", # Resize and rotate
  preset: "slow",      # ffmpeg preset (ultrafast, fast, medium, slow, etc.)
  crf: 23              # Constant Rate Factor (0-51)
})
```

### Screenshots

```ruby
movie = FFmpegCore::Movie.new("input.mp4")

# Extract screenshot at specific time
movie.screenshot("thumbnail.jpg", seek_time: 5)

# With resolution
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

FFmpegCore provides specific error classes for different failure scenarios:

```ruby
begin
  movie = FFmpegCore::Movie.new("input.mp4")
  movie.transcode("output.mp4", video_codec: "libx264")
rescue FFmpegCore::InvalidInputError => e
  # File doesn't exist or is not readable
  puts "Input error: #{e.message}"
rescue FFmpegCore::TranscodingError => e
  # FFmpeg transcoding failed
  puts "Transcoding failed: #{e.message}"
  puts "Command: #{e.command}"
  puts "Exit status: #{e.exit_status}"
  puts "Stderr: #{e.stderr}"
rescue FFmpegCore::BinaryNotFoundError => e
  # FFmpeg not installed
  puts "FFmpeg not found: #{e.message}"
end
```

### Error Classes

| Error                             | Description                            |
| --------------------------------- | -------------------------------------- |
| `FFmpegCore::Error`               | Base error class                       |
| `FFmpegCore::BinaryNotFoundError` | FFmpeg/FFprobe not found               |
| `FFmpegCore::InvalidInputError`   | Input file doesn't exist or unreadable |
| `FFmpegCore::ProbeError`          | Failed to extract metadata             |
| `FFmpegCore::TranscodingError`    | FFmpeg transcoding failed              |
| `FFmpegCore::ScreenshotError`     | Screenshot extraction failed           |

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