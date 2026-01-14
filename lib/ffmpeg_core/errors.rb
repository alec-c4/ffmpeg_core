# frozen_string_literal: true

module FFmpegCore
  # Base error class for all FFmpegCore errors
  class Error < StandardError; end

  # Raised when ffmpeg/ffprobe binary is not found
  class BinaryNotFoundError < Error; end

  # Raised when ffmpeg/ffprobe execution fails
  class ExecutionError < Error
    attr_reader :command, :exit_status, :stdout, :stderr

    def initialize(message, command: nil, exit_status: nil, stdout: nil, stderr: nil)
      @command = command
      @exit_status = exit_status
      @stdout = stdout
      @stderr = stderr
      super(message)
    end
  end

  # Raised when input file is invalid or cannot be read
  class InvalidInputError < Error; end

  # Raised when output file cannot be written
  class OutputError < Error; end

  # Raised when probe fails to extract metadata
  class ProbeError < Error; end

  # Raised when transcoding fails
  class TranscodingError < ExecutionError; end

  # Raised when screenshot extraction fails
  class ScreenshotError < ExecutionError; end
end
