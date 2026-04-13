# frozen_string_literal: true

require "open3"

module FFmpegCore
  # Cut/trim video segments
  class Clipper
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
      cmd = [FFmpegCore.configuration.ffmpeg_binary]

      cmd += ["-ss", options[:start_time].to_s] if options[:start_time]
      cmd += ["-i", input_path]

      if options[:duration]
        cmd += ["-t", options[:duration].to_s]
      elsif options[:end_time]
        cmd += ["-to", options[:end_time].to_s]
      end

      cmd += ["-c", "copy", "-y", output_path]
      cmd
    end

    def execute_command(command)
      _stdout, stderr, status = Open3.capture3(*command)

      unless status.success?
        raise TranscodingError.new(
          "FFmpeg cut failed",
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
