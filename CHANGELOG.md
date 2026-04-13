# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-04-13

### Added

- **Probe — extended metadata:**
  - `subtitle_streams` — array of subtitle streams
  - `chapters` — file chapters (requires ffprobe `-show_chapters`)
  - `format_name` — container format name (mp4, mkv, avi…)
  - `tags` — file-level tags (title, artist, etc.)
  - `audio_sample_rate` — sample rate of the first audio stream
  - `audio_channels` — channel count
  - `audio_channel_layout` — channel layout string (stereo, 5.1…)
  - `pixel_format` — video pixel format (yuv420p, etc.)
  - `has_video?` / `has_audio?` — stream presence predicates
  - `exif` — EXIF tags merged from format and video stream tags (FFmpeg 8.1)
- **Movie — new operations:**
  - `cut(output, start_time:, duration:)` / `cut(output, start_time:, end_time:)` — lossless trim via `-c copy`
  - `extract_audio(output, codec:)` — extract audio track to file
  - `screenshots(output_dir, count:)` — extract multiple screenshots at equal intervals
- **Hardware acceleration — AV1 and D3D12 support (FFmpeg 8.0/8.1):**
  - AV1 via `:nvenc` (`av1_nvenc`), `:vaapi` (`av1_vaapi`), `:vulkan` (`av1_vulkan`)
  - D3D12 via `:d3d12` (`h264_d3d12va`) for Windows

### Changed

- `Probe#probe!` now passes `-show_chapters` to ffprobe

## [0.4.1] - 2026-04-09

### Fixed

- Binary detection on Windows: `where` fallback now correctly resolves ffmpeg/ffprobe when not on PATH

### Changed

- Simplified binary detection: removed redundant Ruby PATH scan, extracted lookup steps into focused private methods
- Expanded `Configuration` spec: ENV override, `BinaryNotFoundError`, known-path fallback, `reset_configuration!`

## [0.4.0] - 2026-01-26

### Added

- **Complex Filters & Mapping:** Added `filter_graph` (for `-filter_complex`) and `maps` (for `-map`) options to `transcode`.
- **Hardware Acceleration:** Added `:hwaccel` option to `transcode` (supports `:nvenc`, `:vaapi`, `:qsv`) with automatic encoder detection.

## [0.3.0] - 2026-01-16

### Added

- **Remote Input Support:** `Movie.new` now accepts HTTP, HTTPS, RTMP, and RTSP URLs.
- **Crop Support:** Added `crop` option to `transcode` (e.g., `crop: { width: 100, height: 100, x: 10, y: 10 }`).
- **Advanced Metadata:** Added `video_profile` and `video_level` to `Probe`.
- Rotation detection from `side_data_list` for better compatibility with newer video formats.

### Fixed

- **Rotation Geometry:** `Probe#width` and `Probe#height` now correctly swap values if the video is rotated 90 or 270 degrees.

## [0.2.0] - 2026-01-15

### Added

- Real-time progress reporting in `Movie#transcode` via block yielding (0.0 to 1.0)
- Support for video and audio filters (`video_filter`, `audio_filter`)
- Support for quality settings (`preset`, `crf`)
- Enhanced metadata in `Probe`: added `rotation`, `aspect_ratio`, and `audio_streams`
- Comprehensive modular test suite for `Transcoder` and `Screenshot`

### Changed

- `Transcoder` now uses `Open3.popen3` for non-blocking execution and progress parsing
- Improved RSpec testing style (using `have_received` spies)

## [0.1.1] - 2026-01-14

### Fixed

- `ProbeError` now inherits from `ExecutionError` to properly accept keyword arguments (Ruby 4.0 compatibility)

## [0.1.0] - 2026-01-14

### Added

- `FFmpegCore::Movie` - main API for working with video files
- `FFmpegCore::Probe` - extract video metadata using ffprobe
- `FFmpegCore::Transcoder` - transcode videos with various options
- `FFmpegCore::Screenshot` - extract screenshots from videos
- `FFmpegCore::Configuration` - thread-safe global configuration
- Automatic ffmpeg/ffprobe binary detection
- Comprehensive error classes with detailed context
