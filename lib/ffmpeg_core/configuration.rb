# frozen_string_literal: true

module FFmpegCore
  # Configuration for FFmpegCore library
  class Configuration
    attr_accessor :ffmpeg_binary, :ffprobe_binary, :timeout

    def initialize
      @ffmpeg_binary = detect_binary("ffmpeg")
      @ffprobe_binary = detect_binary("ffprobe")
      @timeout = 30 # seconds
    end

    private

    def detect_binary(name)
      # Check common locations
      paths = ENV["PATH"].split(File::PATH_SEPARATOR)
      paths.each do |path|
        binary = File.join(path, name)
        return binary if File.executable?(binary)
      end

      # Homebrew locations (macOS)
      homebrew_paths = [
        "/opt/homebrew/bin/#{name}", # Apple Silicon
        "/usr/local/bin/#{name}" # Intel
      ]
      homebrew_paths.each do |path|
        return path if File.executable?(path)
      end

      raise BinaryNotFoundError, "#{name} binary not found. Please install FFmpeg: brew install ffmpeg"
    end
  end

  class << self
    def configuration
      @configuration_mutex ||= Mutex.new
      @configuration_mutex.synchronize do
        @configuration ||= Configuration.new
      end
    end

    def configuration=(config)
      @configuration_mutex ||= Mutex.new
      @configuration_mutex.synchronize do
        @configuration = config
      end
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration_mutex ||= Mutex.new
      @configuration_mutex.synchronize do
        @configuration = Configuration.new
      end
    end
  end
end
