# frozen_string_literal: true

require "fileutils"
require "forwardable"

# FFmpegCore - Modern Ruby wrapper for FFmpeg
#
# A clean, well-tested alternative to streamio-ffmpeg with:
# - Modern Ruby 3+ conventions
# - Proper error handling with detailed context
# - Zero Rails dependencies (gem-ready architecture)
#
# @example Basic usage
#   movie = FFmpegCore::Movie.new("input.mp4")
#   movie.transcode("output.mp4", video_codec: "libx264", video_bitrate: "1000k")
#   movie.screenshot("thumb.jpg", seek_time: 1, resolution: "640x360")
module FFmpegCore
end

# Load core components
require_relative "ffmpeg_core/version"
require_relative "ffmpeg_core/errors"
require_relative "ffmpeg_core/configuration"
require_relative "ffmpeg_core/probe"
require_relative "ffmpeg_core/transcoder"
require_relative "ffmpeg_core/screenshot"
require_relative "ffmpeg_core/movie"
