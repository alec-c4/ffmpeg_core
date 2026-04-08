# frozen_string_literal: true

RSpec.describe FFmpegCore::Configuration do
  describe "#initialize" do
    it "detects ffmpeg binary" do
      config = described_class.new
      expect(config.ffmpeg_binary).to include("ffmpeg")
    end

    it "detects ffprobe binary" do
      config = described_class.new
      expect(config.ffprobe_binary).to include("ffprobe")
    end

    it "sets default timeout to 30 seconds" do
      expect(described_class.new.timeout).to eq(30)
    end
  end

  describe "#detect_binary (via initialize)" do
    context "when FFMPEGCORE_FFMPEG points to an executable file" do
      it "uses the env override" do
        allow(File).to receive(:executable?).and_call_original
        allow(File).to receive(:executable?).with("/custom/ffmpeg").and_return(true)

        with_env("FFMPEGCORE_FFMPEG" => "/custom/ffmpeg") do
          config = described_class.new
          expect(config.ffmpeg_binary).to eq("/custom/ffmpeg")
        end
      end
    end

    context "when FFMPEGCORE_FFMPEG points to a non-executable path" do
      it "falls through to system lookup" do
        allow(File).to receive(:executable?).and_call_original
        allow(File).to receive(:executable?).with("/not/executable").and_return(false)

        with_env("FFMPEGCORE_FFMPEG" => "/not/executable") do
          # Should not raise — falls through to which/where and finds real ffmpeg
          expect { described_class.new }.not_to raise_error
        end
      end
    end

    context "when binary is not found anywhere" do
      before do
        # Make all File.executable? checks return false
        allow(File).to receive(:executable?).and_return(false)
        # Make system lookup fail
        allow(Open3).to receive(:capture2).and_return(["", double(success?: false)])
      end

      # Restore real behaviour before spec_helper's global `after` runs
      # `reset_configuration!`, otherwise the stubs make *that* raise too.
      after do
        allow(File).to receive(:executable?).and_call_original
        allow(Open3).to receive(:capture2).and_call_original
      end

      it "raises BinaryNotFoundError with install instructions" do
        expect { described_class.new }.to raise_error(
          FFmpegCore::BinaryNotFoundError,
          /ffmpeg not found/i
        )
      end

      it "includes platform hints in the error message" do
        expect { described_class.new }.to raise_error(
          FFmpegCore::BinaryNotFoundError,
          /brew install ffmpeg/
        )
      end
    end

    context "when binary is not in PATH but exists at a known location" do
      let(:known_ffmpeg_path) { "/opt/homebrew/bin/ffmpeg" }
      let(:known_ffprobe_path) { "/opt/homebrew/bin/ffprobe" }

      before do
        allow(File).to receive(:executable?).and_return(false)
        allow(File).to receive(:executable?).with(known_ffmpeg_path).and_return(true)
        allow(File).to receive(:executable?).with(known_ffprobe_path).and_return(true)
        allow(Open3).to receive(:capture2).and_return(["", double(success?: false)])
      end

      # Same reason as above: restore real methods before global after hook fires.
      after do
        allow(File).to receive(:executable?).and_call_original
        allow(Open3).to receive(:capture2).and_call_original
      end

      it "finds the binary at the known location" do
        config = described_class.new
        expect(config.ffmpeg_binary).to eq(known_ffmpeg_path)
      end
    end
  end

  describe "#encoders" do
    it "returns a set of encoder names" do
      expect(described_class.new.encoders).to be_a(Set)
    end

    it "includes common encoders" do
      encoders = described_class.new.encoders
      expect(encoders).to include("libx264").or include("aac")
    end

    it "returns empty Set when ffmpeg binary is nil" do
      config = described_class.new
      config.ffmpeg_binary = nil
      expect(config.encoders).to eq(Set.new)
    end
  end
end

RSpec.describe FFmpegCore do
  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(FFmpegCore::Configuration)
    end

    it "returns the same instance on subsequent calls" do
      first = described_class.configuration
      second = described_class.configuration
      expect(first).to equal(second)
    end
  end

  describe ".configure" do
    it "yields the configuration object" do
      described_class.configure do |config|
        config.timeout = 60
      end

      expect(described_class.configuration.timeout).to eq(60)
    end
  end

  describe ".reset_configuration!" do
    it "resets to a fresh Configuration instance" do
      original = described_class.configuration
      described_class.reset_configuration!
      expect(described_class.configuration).not_to equal(original)
    end
  end
end

# Helpers

def with_env(vars, &block)
  old = vars.transform_values { |key| ENV.fetch(key, nil) }
  vars.each { |k, v| ENV[k] = v }
  yield
ensure
  vars.each { |k, _| old[k].nil? ? ENV.delete(k) : ENV.store(k, old[k]) }
end
