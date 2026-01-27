# frozen_string_literal: true

require_relative "lib/ffmpeg_core/version"

Gem::Specification.new do |spec|
  spec.name = "ffmpeg_core"
  spec.version = FFmpegCore::VERSION
  spec.authors = ["Alexey Poimtsev"]
  spec.email = ["alexey.poimtsev@gmail.com"]

  spec.summary = "Modern Ruby wrapper for FFmpeg"
  spec.description = "A clean, well-tested FFmpeg wrapper with modern Ruby conventions, proper error handling, and zero dependencies."
  spec.homepage = "https://github.com/alec-c4/ffmpeg_core"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/alec-c4/ffmpeg_core"
  spec.metadata["changelog_uri"] = "https://github.com/alec-c4/ffmpeg_core/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "simplecov"
end
