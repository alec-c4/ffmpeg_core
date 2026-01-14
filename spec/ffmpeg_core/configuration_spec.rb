# frozen_string_literal: true

RSpec.describe FFmpegCore::Configuration do
  describe "#initialize" do
    it "detects ffmpeg binary" do
      config = described_class.new
      expect(config.ffmpeg_binary).not_to be_nil
      expect(config.ffmpeg_binary).to include("ffmpeg")
    end

    it "detects ffprobe binary" do
      config = described_class.new
      expect(config.ffprobe_binary).not_to be_nil
      expect(config.ffprobe_binary).to include("ffprobe")
    end

    it "sets default timeout" do
      config = described_class.new
      expect(config.timeout).to eq(30)
    end
  end
end

RSpec.describe FFmpegCore do
  describe ".configuration" do
    it "returns configuration instance" do
      expect(described_class.configuration).to be_a(FFmpegCore::Configuration)
    end
  end

  describe ".configure" do
    it "yields configuration block" do
      described_class.configure do |config|
        config.timeout = 60
      end

      expect(described_class.configuration.timeout).to eq(60)
    end
  end
end
