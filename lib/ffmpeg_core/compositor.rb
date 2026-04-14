# frozen_string_literal: true

require "open3"

module FFmpegCore
  # Execute FFmpeg operations with multiple input files
  #
  # @example Overlay (picture-in-picture)
  #   FFmpegCore::Compositor.new(
  #     ["background.mp4", "overlay.mp4"],
  #     "output.mp4",
  #     filter_complex: "[0:v][1:v]overlay=10:10[v]",
  #     maps: ["[v]", "0:a"]
  #   ).run
  #
  # @example Concatenate
  #   FFmpegCore::Compositor.new(
  #     ["part1.mp4", "part2.mp4"],
  #     "output.mp4",
  #     filter_complex: "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[v][a]",
  #     maps: ["[v]", "[a]"]
  #   ).run
  class Compositor
    attr_reader :input_paths, :output_path, :options

    # @param input_paths [Array<String>] Paths or URLs to input files (at least one required)
    # @param output_path [String] Path to output file
    # @param options [Hash] Compositing options
    # @option options [String] :video_codec Video codec (e.g., "libx264")
    # @option options [String] :audio_codec Audio codec (e.g., "aac")
    # @option options [String, Integer] :video_bitrate Video bitrate (e.g., "1000k" or 1000)
    # @option options [String, Integer] :audio_bitrate Audio bitrate (e.g., "128k" or 128)
    # @option options [Array<String>, String] :filter_complex FFmpeg filter graph referencing input streams by index
    #   (e.g., "[0:v][1:v]overlay=0:0[v]"). Array elements are joined with semicolons.
    # @option options [Array<String>, String] :maps Stream maps selecting outputs from the filter graph
    #   (e.g., ["[v]", "0:a"])
    # @option options [Float] :duration Total duration in seconds, used for progress reporting
    # @option options [Array<String>] :custom Raw FFmpeg flags appended verbatim (e.g., ["-shortest"])
    # @raise [ArgumentError] if input_paths is empty
    def initialize(input_paths, output_path, options = {})
      raise ArgumentError, "At least one input path is required" if Array(input_paths).empty?

      @input_paths = Array(input_paths).map(&:to_s)
      @output_path = output_path.to_s
      @options = options
    end

    # Run the FFmpeg compositing command
    #
    # @yield [Float] Progress ratio from 0.0 to 1.0 (requires :duration option)
    # @return [String] Path to the output file
    # @raise [InvalidInputError] if a local input file does not exist
    # @raise [TranscodingError] if FFmpeg exits with a non-zero status
    def run(&block)
      validate_inputs!
      ensure_output_directory!

      command = build_command
      execute_command(command, &block)
    end

    private

    def validate_inputs!
      input_paths.each do |path|
        next if %r{^(https?|rtmp|rtsp)://}.match?(path)

        raise InvalidInputError, "Input file does not exist: #{path}" unless File.exist?(path)
      end
    end

    def ensure_output_directory!
      output_dir = File.dirname(output_path)
      FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)
    end

    def build_command
      cmd = [FFmpegCore.configuration.ffmpeg_binary]

      input_paths.each { |path| cmd += ["-i", path] }

      cmd += ["-c:v", options[:video_codec]] if options[:video_codec]
      cmd += ["-c:a", options[:audio_codec]] if options[:audio_codec]
      cmd += ["-b:v", normalize_bitrate(options[:video_bitrate])] if options[:video_bitrate]
      cmd += ["-b:a", normalize_bitrate(options[:audio_bitrate])] if options[:audio_bitrate]

      filter = options[:filter_complex] || options[:filter_graph]
      if filter
        cmd += ["-filter_complex", filter.is_a?(Array) ? filter.join(";") : filter]
      end

      maps = options[:maps] || options[:map]
      Array(maps).each { |map| cmd += ["-map", map] } if maps

      cmd += options[:custom] if options[:custom]
      cmd += ["-y", output_path]
      cmd
    end

    def normalize_bitrate(bitrate)
      return bitrate.to_s if bitrate.to_s.match?(/\d+[kKmM]/)

      "#{bitrate}k"
    end

    def execute_command(command, &block)
      error_log = []

      Open3.popen3(*command) do |_stdin, _stdout, stderr, wait_thr|
        stderr.each_line("\r") do |line|
          clean_line = line.strip
          next if clean_line.empty?

          error_log << clean_line
          error_log.shift if error_log.size > 20
          parse_progress(line, &block) if block
        end

        status = wait_thr.value
        unless status.success?
          raise TranscodingError.new(
            "FFmpeg compositing failed",
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
      return unless line =~ /time=(\d{2}):(\d{2}):(\d{2}\.\d{2})/

      current_time = $1.to_i * 3600 + $2.to_i * 60 + $3.to_f
      duration = options[:duration]
      yield([current_time / duration.to_f, 1.0].min) if duration && duration.to_f > 0
    end
  end
end
