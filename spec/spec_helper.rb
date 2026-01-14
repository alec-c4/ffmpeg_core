# frozen_string_literal: true

require "ffmpeg_core"
require "fileutils"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Helper to get fixture path
  config.add_setting :fixtures_path
  config.fixtures_path = File.expand_path("fixtures/files", __dir__)

  # Reset configuration after each test
  config.after do
    FFmpegCore.reset_configuration!
  end
end

def fixture_path(filename)
  File.join(RSpec.configuration.fixtures_path, filename)
end

def tmp_path(filename)
  path = File.expand_path("../../tmp", __dir__)
  FileUtils.mkdir_p(path)
  File.join(path, filename)
end
