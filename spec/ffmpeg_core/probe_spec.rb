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
        expect do
          described_class.new("/nonexistent/video.mp4")
        end.to raise_error(FFmpegCore::InvalidInputError, /does not exist/)
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

    context "with complex metadata" do
      let(:complex_json) do
        {
          "streams" => [
            {
              "codec_type" => "video",
              "tags" => {"rotate" => "90"},
              "display_aspect_ratio" => "16:9"
            },
            {"codec_type" => "audio", "index" => 1},
            {"codec_type" => "audio", "index" => 2}
          ]
        }.to_json
      end
      let(:probe_complex) { described_class.new(video_path) }

      before do
        # Mock Open3 to return our complex JSON instead of running ffprobe
        allow(Open3).to receive(:capture3).and_return([complex_json, "", double(success?: true)])
      end

      it "extracts rotation" do
        expect(probe_complex.rotation).to eq(90)
      end

      it "extracts aspect ratio" do
        expect(probe_complex.aspect_ratio).to eq("16:9")
      end

      it "finds multiple audio streams" do
        expect(probe_complex.audio_streams.count).to eq(2)
      end
    end
  end
end
