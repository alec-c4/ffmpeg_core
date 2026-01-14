# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
