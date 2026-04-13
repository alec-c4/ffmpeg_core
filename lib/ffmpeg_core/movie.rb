# frozen_string_literal: true

module FFmpegCore
  # Modern API for working with video files
  class Movie
    extend Forwardable

    attr_reader :path, :probe

    def initialize(path)
      @path = path
      @probe = Probe.new(path)
    end

    # Delegate metadata methods to probe
    def_delegators :probe, :duration, :bitrate, :video_codec, :audio_codec,
      :width, :height, :frame_rate, :resolution, :valid?

    # Transcode video with modern API
    #
    # @param output_path [String] Path to output file
    # @param options [Hash] Transcoding options
    # @option options [String] :video_codec Video codec (e.g., "libx264")
    # @option options [String] :audio_codec Audio codec (e.g., "aac")
    # @option options [String, Integer] :video_bitrate Video bitrate (e.g., "1000k" or 1000)
    # @option options [String, Integer] :audio_bitrate Audio bitrate (e.g., "128k" or 128)
    # @option options [String] :resolution Resolution (e.g., "1280x720")
    # @option options [Integer, Float] :frame_rate Frame rate (e.g., 30)
    # @option options [Array<String>, String] :filter_graph Complex filter graph (e.g., ["[0:v]crop=..."])
    # @option options [Array<String>, String] :maps Stream maps (e.g., ["[outv]", "0:a"])
    # @option options [Symbol] :hwaccel Hardware acceleration (:nvenc, :vaapi, :qsv)
    # @option options [Array<String>] :custom Custom FFmpeg flags
    # @yield [Float] Progress ratio (0.0 to 1.0)
    # @return [String] Path to transcoded file
    def transcode(output_path, options = {}, &block)
      # Inject duration for progress calculation if known
      options[:duration] ||= duration

      transcoder = Transcoder.new(path, output_path, options)
      transcoder.run(&block)
    end

    # Extract screenshot from video
    #
    # @param output_path [String] Path to output image
    # @param options [Hash] Screenshot options
    # @option options [Integer, Float] :seek_time Time in seconds to seek to (default: 0)
    # @option options [String] :resolution Resolution (e.g., "640x360")
    # @option options [Integer] :quality JPEG quality 2-31, lower is better (default: 2)
    # @return [String] Path to screenshot file
    def screenshot(output_path, options = {})
      screenshotter = Screenshot.new(path, output_path, options)
      screenshotter.extract
    end

    # Cut/trim a segment from video
    #
    # @param output_path [String] Path to output file
    # @param options [Hash] Cut options
    # @option options [Integer, Float] :start_time Start time in seconds
    # @option options [Integer, Float] :duration Duration in seconds
    # @option options [Integer, Float] :end_time End time in seconds (alternative to :duration)
    # @return [String] Path to output file
    def cut(output_path, options = {})
      clipper = Clipper.new(path, output_path, options)
      clipper.run
    end

    # Extract audio track from video
    #
    # @param output_path [String] Path to output audio file
    # @param options [Hash] Extraction options
    # @option options [String] :codec Audio codec (e.g., "libmp3lame", "aac")
    # @return [String] Path to output file
    def extract_audio(output_path, options = {})
      extractor = AudioExtractor.new(path, output_path, options)
      extractor.run
    end

    # Extract multiple screenshots at equal intervals
    #
    # @param output_dir [String] Directory to save screenshots
    # @param count [Integer] Number of screenshots to extract (default: 5)
    # @return [Array<String>] Paths to screenshot files
    def screenshots(output_dir, count: 5)
      FileUtils.mkdir_p(output_dir)
      total = duration || 0
      interval = total / (count + 1).to_f

      (1..count).map do |i|
        seek = (interval * i).round(2)
        output_path = File.join(output_dir, format("screenshot_%03d.jpg", i))
        Screenshot.new(path, output_path, seek_time: seek).extract
        output_path
      end
    end
  end
end
