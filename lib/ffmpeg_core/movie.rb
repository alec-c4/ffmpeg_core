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
    # @option options [Array<String>] :custom Custom FFmpeg flags
    # @return [String] Path to transcoded file
    def transcode(output_path, options = {})
      transcoder = Transcoder.new(path, output_path, options)
      transcoder.run
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
  end
end
