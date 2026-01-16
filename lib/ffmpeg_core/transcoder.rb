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

    def run(&block)
      validate_input!
      ensure_output_directory!

      command = build_command
      execute_command(command, &block)
    end

    private

    def validate_input!
      return if input_path =~ %r{^(https?|rtmp|rtsp)://}

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
      cmd += ["-c:v", options[:video_codec]] if options[:video_codec]

      # Audio codec
      cmd += ["-c:a", options[:audio_codec]] if options[:audio_codec]

      # Video bitrate
      cmd += ["-b:v", normalize_bitrate(options[:video_bitrate])] if options[:video_bitrate]

      # Audio bitrate
      cmd += ["-b:a", normalize_bitrate(options[:audio_bitrate])] if options[:audio_bitrate]

      # Resolution
      cmd += ["-s", options[:resolution]] if options[:resolution]

      # Frame rate
      cmd += ["-r", options[:frame_rate].to_s] if options[:frame_rate]

      # Video filters
      video_filters = []
      video_filters << options[:video_filter] if options[:video_filter]
      
      if options[:crop]
        crop = options[:crop]
        video_filters << "crop=#{crop[:width]}:#{crop[:height]}:#{crop[:x]}:#{crop[:y]}"
      end
      
      cmd += ["-vf", video_filters.join(",")] unless video_filters.empty?

      # Audio filter
      cmd += ["-af", options[:audio_filter]] if options[:audio_filter]

      # Quality preset
      cmd += ["-preset", options[:preset]] if options[:preset]

      # Constant Rate Factor (CRF)
      cmd += ["-crf", options[:crf].to_s] if options[:crf]

      # Custom options (array of strings)
      cmd += options[:custom] if options[:custom]

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

    def execute_command(command, &block)
      # Keep track of last few lines for error reporting
      error_log = []

      Open3.popen3(*command) do |_stdin, _stdout, stderr, wait_thr|
        # FFmpeg uses \r to update progress line, so we split by \r
        # We also handle \n just in case
        stderr.each_line("\r") do |line|
          clean_line = line.strip
          next if clean_line.empty?

          error_log << clean_line
          error_log.shift if error_log.size > 20 # Keep last 20 lines

          parse_progress(clean_line, &block) if block_given?
        end

        status = wait_thr.value

        unless status.success?
          raise TranscodingError.new(
            "FFmpeg transcoding failed",
            command: command.join(" "),
            exit_status: status.exitstatus,
            stdout: "",
            stderr: error_log.join("\n")
          )
        end
      end

      output_path
    end

    def parse_progress(line)
      # Match time=HH:MM:SS.ms
      if line =~ /time=(\d{2}):(\d{2}):(\d{2}\.\d{2})/
        hours, minutes, seconds = $1.to_i, $2.to_i, $3.to_f
        current_time = (hours * 3600) + (minutes * 60) + seconds

        duration = options[:duration]
        if duration && duration.to_f > 0
          progress = [current_time / duration.to_f, 1.0].min
          yield(progress)
        end
      end
    end
  end
end
