# frozen_string_literal: true

require "open3"

module FFmpegCore
  # Extract screenshots from video files
  class Screenshot
    attr_reader :input_path, :output_path, :options

    def initialize(input_path, output_path, options = {})
      @input_path = input_path.to_s
      @output_path = output_path.to_s
      @options = options
    end

    def extract
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

      # Seek to timestamp (before input for faster processing)
      if options[:seek_time]
        cmd += ["-ss", options[:seek_time].to_s]
      end

      # Input file
      cmd += ["-i", input_path]

      # Number of frames to extract (default: 1)
      cmd += ["-vframes", "1"]

      # Resolution
      if options[:resolution]
        cmd += ["-s", options[:resolution]]
      end

      # Quality (2-31, lower is better, default: 2)
      quality = options[:quality] || 2
      cmd += ["-q:v", quality.to_s]

      # Overwrite output file
      cmd += ["-y"]

      # Output file
      cmd += [output_path]

      cmd
    end

    def execute_command(command)
      stdout, stderr, status = Open3.capture3(*command)

      unless status.success?
        raise ScreenshotError.new(
          "Screenshot extraction failed",
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
