# frozen_string_literal: true

require "json"
require "open3"

module FFmpegCore
  # Probe video metadata using ffprobe
  class Probe
    attr_reader :path, :metadata

    def initialize(path)
      @path = path.to_s
      @metadata = nil
      validate_file!
      probe!
    end

    # Duration in seconds
    def duration
      @metadata.dig("format", "duration")&.to_f
    end

    # Bitrate in kb/s
    def bitrate
      @metadata.dig("format", "bit_rate")&.to_i&./(1000)
    end

    # Video stream metadata
    def video_stream
      @video_stream ||= streams.find { |s| s["codec_type"] == "video" }
    end

    # Audio stream metadata
    def audio_stream
      @audio_stream ||= streams.find { |s| s["codec_type"] == "audio" }
    end

    def video_codec
      video_stream&.dig("codec_name")
    end

    def video_profile
      video_stream&.dig("profile")
    end

    def video_level
      video_stream&.dig("level")
    end

    def audio_codec
      audio_stream&.dig("codec_name")
    end

    def width
      val = video_stream&.dig("width")
      return val unless val
      return val if (rotation || 0) % 180 == 0

      video_stream&.dig("height")
    end

    def height
      val = video_stream&.dig("height")
      return val unless val
      return val if (rotation || 0) % 180 == 0

      video_stream&.dig("width")
    end

    def frame_rate
      return nil unless video_stream

      # Parse frame rate (e.g., "30000/1001" or "30")
      r_frame_rate = video_stream["r_frame_rate"]
      return nil unless r_frame_rate

      if r_frame_rate.include?("/")
        num, den = r_frame_rate.split("/").map(&:to_f)
        num / den
      else
        r_frame_rate.to_f
      end
    end

    def resolution
      return nil unless width && height

      "#{width}x#{height}"
    end

    def rotation
      return nil unless video_stream

      # Try to find rotation in tags (common in MP4/MOV)
      tags = video_stream.fetch("tags", {})
      return tags["rotate"].to_i if tags["rotate"]

      # Try side_data_list (common in some newer formats)
      side_data = video_stream.fetch("side_data_list", []).find { |sd| sd.key?("rotation") }
      return side_data["rotation"].to_i if side_data

      # Default to 0 if not found
      0
    end

    def aspect_ratio
      video_stream&.dig("display_aspect_ratio")
    end

    def audio_streams
      streams.select { |s| s["codec_type"] == "audio" }
    end

    def subtitle_streams
      streams.select { |s| s["codec_type"] == "subtitle" }
    end

    def chapters
      @metadata.fetch("chapters", [])
    end

    def format_name
      @metadata.dig("format", "format_name")
    end

    def tags
      @metadata.dig("format", "tags") || {}
    end

    def audio_sample_rate
      audio_stream&.dig("sample_rate")&.to_i
    end

    def audio_channels
      audio_stream&.dig("channels")
    end

    def audio_channel_layout
      audio_stream&.dig("channel_layout")
    end

    def pixel_format
      video_stream&.dig("pix_fmt")
    end

    def has_video?
      !video_stream.nil?
    end

    def has_audio?
      !audio_stream.nil?
    end

    # EXIF metadata: merges format-level and video stream tags (FFmpeg 8.1+)
    def exif
      format_tags = @metadata.dig("format", "tags") || {}
      stream_tags = video_stream&.dig("tags") || {}
      format_tags.merge(stream_tags)
    end

    def valid?
      !video_stream.nil?
    end

    private

    def streams
      @metadata.fetch("streams", [])
    end

    def validate_file!
      return if %r{^(https?|rtmp|rtsp)://}.match?(path)

      raise InvalidInputError, "File does not exist: #{path}" unless File.exist?(path)
      raise InvalidInputError, "File is not readable: #{path}" unless File.readable?(path)
    end

    def probe!
      command = [
        FFmpegCore.configuration.ffprobe_binary,
        "-v", "quiet",
        "-print_format", "json",
        "-show_format",
        "-show_streams",
        "-show_chapters",
        path
      ]

      stdout, stderr, status = Open3.capture3(*command)

      unless status.success?
        raise ProbeError.new(
          "ffprobe failed for #{path}",
          command: command.join(" "),
          exit_status: status.exitstatus,
          stdout: stdout,
          stderr: stderr
        )
      end

      @metadata = JSON.parse(stdout)
    rescue JSON::ParserError => e
      raise ProbeError, "Failed to parse ffprobe output: #{e.message}"
    end
  end
end
