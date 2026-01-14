# frozen_string_literal: true

require "open3"
require "shellwords"

module FFmpegCore
  # Execute FFmpeg transcoding operations
  class Transcoder
    attr_reader :input_path, :output_path, :options

    def initialize(input_path, output_path, options = {})
      @input_path = input_path.to_s
      @output_path = output_path.to_s
      @options = options
    end

    def run
      validate_input!
      ensure_output_directory!

      command = build_command
      execute_command(command)
    end

    private

    def validate_input!
      raise InvalidInputError, "Input file does not exist: #{input_path}" unless File.exist?(input_path)
    end

    def ensure_output_directory!
      output_dir = File.dirname(output_path)
      FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)
    end

    def build_command
      cmd = [FFmpegCore.configuration.ffmpeg_binary]

      # Input file
      cmd += ["-i", input_path]

      # Video codec
      if options[:video_codec]
        cmd += ["-c:v", options[:video_codec]]
      end

      # Audio codec
      if options[:audio_codec]
        cmd += ["-c:a", options[:audio_codec]]
      end

      # Video bitrate
      if options[:video_bitrate]
        cmd += ["-b:v", normalize_bitrate(options[:video_bitrate])]
      end

      # Audio bitrate
      if options[:audio_bitrate]
        cmd += ["-b:a", normalize_bitrate(options[:audio_bitrate])]
      end

      # Resolution
      if options[:resolution]
        cmd += ["-s", options[:resolution]]
      end

      # Frame rate
      if options[:frame_rate]
        cmd += ["-r", options[:frame_rate].to_s]
      end

      # Custom options (array of strings)
      if options[:custom]
        cmd += options[:custom]
      end

      # Overwrite output file
      cmd += ["-y"]

      # Output file
      cmd += [output_path]

      cmd
    end

    def normalize_bitrate(bitrate)
      # Convert various formats to ffmpeg format
      # "1000k" -> "1000k"
      # 1000 -> "1000k"
      # "1M" -> "1M"
      return bitrate.to_s if bitrate.to_s.match?(/\d+[kKmM]/)
      "#{bitrate}k"
    end

    def execute_command(command)
      stdout, stderr, status = Open3.capture3(*command)

      unless status.success?
        raise TranscodingError.new(
          "FFmpeg transcoding failed",
          command: command.join(" "),
          exit_status: status.exitstatus,
          stdout: stdout,
          stderr: stderr
        )
      end

      output_path
    end
  end
end
