# frozen_string_literal: true

require "open3"

module FFmpegCore
  # Extract audio track from video files
  class AudioExtractor
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
      return if %r{^(https?|rtmp|rtsp)://}.match?(input_path)

      raise InvalidInputError, "Input file does not exist: #{input_path}" unless File.exist?(input_path)
    end

    def ensure_output_directory!
      output_dir = File.dirname(output_path)
      FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)
    end

    def build_command
      cmd = [FFmpegCore.configuration.ffmpeg_binary, "-i", input_path]
      cmd += ["-vn"]
      cmd += ["-c:a", options[:codec]] if options[:codec]
      cmd += ["-y", output_path]
      cmd
    end

    def execute_command(command)
      _stdout, stderr, status = Open3.capture3(*command)

      unless status.success?
        raise TranscodingError.new(
          "FFmpeg audio extraction failed",
          command: command.join(" "),
          exit_status: status.exitstatus,
          stdout: "",
          stderr: stderr
        )
      end

      output_path
    end
  end
end
