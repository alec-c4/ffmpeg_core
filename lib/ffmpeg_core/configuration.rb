# frozen_string_literal: true

require "fileutils"
require "forwardable"
require "open3"

module FFmpegCore
  # Configuration for FFmpegCore library
  class Configuration
    attr_accessor :ffmpeg_binary, :ffprobe_binary, :timeout

    def initialize
      @ffmpeg_binary = detect_binary("ffmpeg")
      @ffprobe_binary = detect_binary("ffprobe")
      @timeout = 30 # seconds
    end

    def encoders
      @encoders ||= detect_encoders
    end

    private

    def detect_encoders
      return Set.new unless @ffmpeg_binary

      stdout, _stderr, status = Open3.capture3(@ffmpeg_binary, "-encoders")
      return Set.new unless status.success?

      encoders = Set.new
      stdout.each_line do |line|
        # Match lines like: " V..... libx264 ..."
        if line =~ /^\s*[VAS][\w.]+\s+(\w+)/
          encoders.add($1)
        end
      end
      encoders
    rescue
      Set.new
    end

    def detect_binary(name)
      binary_from_env(name) ||
        binary_from_system_lookup(name) ||
        binary_from_known_paths(name) ||
        raise(BinaryNotFoundError, <<~MSG)
          #{name} not found.
          Install FFmpeg and ensure it's in PATH.
          macOS: brew install ffmpeg
          Linux: apt install ffmpeg / yum install ffmpeg
          Windows: choco install ffmpeg or scoop install ffmpeg
        MSG
    end

    # Checks FFMPEGCORE_<NAME> env variable for an explicit binary override.
    def binary_from_env(name)
      path = ENV["FFMPEGCORE_#{name.upcase}"]
      path if path && File.executable?(path)
    end

    # Uses the OS-native `which` (Unix) or `where` (Windows) command.
    def binary_from_system_lookup(name)
      cmd = Gem.win_platform? ? "where #{name}" : "which #{name}"
      stdout, status = Open3.capture2(cmd)
      return unless status.success?

      path = stdout.lines.first&.strip
      path if path && File.executable?(path)
    end

    # Falls back to a list of well-known installation paths.
    def binary_from_known_paths(name)
      known_paths(name).find { |p| File.executable?(p) }
    end

    def known_paths(name)
      if Gem.win_platform?
        [
          "C:/ffmpeg/bin/#{name}.exe",
          "C:/ProgramData/chocolatey/bin/#{name}.exe",
          "#{ENV["USERPROFILE"]}/scoop/apps/ffmpeg/current/bin/#{name}.exe"
        ]
      else
        [
          "/opt/homebrew/bin/#{name}",  # macOS ARM
          "/usr/local/bin/#{name}",     # macOS Intel / Linux
          "/usr/bin/#{name}",
          "/snap/bin/#{name}"
        ]
      end
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
