# frozen_string_literal: true

RSpec.describe FFmpegCore::Probe do
  let(:video_path) { fixture_path("sample_video.mp4") }

  describe "#initialize" do
    context "with valid video file" do
      it "probes video metadata" do
        probe = described_class.new(video_path)
        expect(probe.metadata).not_to be_nil
      end
    end

    context "with non-existent file" do
      it "raises InvalidInputError" do
        expect {
          described_class.new("/nonexistent/video.mp4")
        }.to raise_error(FFmpegCore::InvalidInputError, /does not exist/)
      end
    end
  end

  describe "metadata extraction" do
    let(:probe) { described_class.new(video_path) }

    it "extracts duration" do
      expect(probe.duration).to be_a(Float)
      expect(probe.duration).to be > 0
    end

    it "extracts video codec" do
      expect(probe.video_codec).not_to be_nil
    end

    it "extracts dimensions" do
      expect(probe.width).to be_a(Integer)
      expect(probe.height).to be_a(Integer)
      expect(probe.resolution).to match(/\d+x\d+/)
    end

    it "validates video" do
      expect(probe.valid?).to be true
    end
  end
end
