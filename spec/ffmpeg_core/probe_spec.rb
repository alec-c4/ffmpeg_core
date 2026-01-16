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

    context "with remote url" do
      before do
        allow(Open3).to receive(:capture3).and_return(["{}", "", double(success?: true)])
      end

      it "does not check for file existence" do
        expect do
          described_class.new("http://example.com/video.mp4")
        end.not_to raise_error
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
              "width" => 1920,
              "height" => 1080,
              "tags" => {"rotate" => "90"},
              "side_data_list" => [{"rotation" => -90}],
              "profile" => "High",
              "level" => 51,
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
      
      it "swaps width and height based on rotation" do
        # Rotation is 90, so width (1920) becomes height, height (1080) becomes width
        expect(probe_complex.width).to eq(1080)
        expect(probe_complex.height).to eq(1920)
      end
      
      it "extracts profile and level" do
        expect(probe_complex.video_profile).to eq("High")
        expect(probe_complex.video_level).to eq(51)
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
