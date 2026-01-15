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

    def audio_codec
      audio_stream&.dig("codec_name")
    end

    def width
      video_stream&.dig("width")
    end

    def height
      video_stream&.dig("height")
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

      # Default to 0 if not found
      0
    end

    def aspect_ratio
      video_stream&.dig("display_aspect_ratio")
    end

    def audio_streams
      streams.select { |s| s["codec_type"] == "audio" }
    end

    def valid?
      !video_stream.nil?
    end

    private

    def streams
      @metadata.fetch("streams", [])
    end

    def validate_file!
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
