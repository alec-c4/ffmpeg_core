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

    context "with rich metadata" do
      let(:rich_json) do
        {
          "format" => {
            "format_name" => "mov,mp4,m4a,3gp,3g2,mj2",
            "tags" => {"title" => "My Video", "artist" => "Author"}
          },
          "streams" => [
            {
              "codec_type" => "video",
              "width" => 1280,
              "height" => 720,
              "pix_fmt" => "yuv420p"
            },
            {
              "codec_type" => "audio",
              "sample_rate" => "48000",
              "channels" => 2,
              "channel_layout" => "stereo"
            },
            {
              "codec_type" => "subtitle",
              "codec_name" => "subrip",
              "index" => 2
            }
          ],
          "chapters" => [
            {"id" => 0, "start_time" => "0.000000", "end_time" => "60.000000",
             "tags" => {"title" => "Intro"}},
            {"id" => 1, "start_time" => "60.000000", "end_time" => "120.000000",
             "tags" => {"title" => "Main"}}
          ]
        }.to_json
      end
      let(:probe_rich) { described_class.new(video_path) }

      before do
        allow(Open3).to receive(:capture3).and_return([rich_json, "", double(success?: true)])
      end

      it "extracts format_name" do
        expect(probe_rich.format_name).to eq("mov,mp4,m4a,3gp,3g2,mj2")
      end

      it "extracts file-level tags" do
        expect(probe_rich.tags).to eq("title" => "My Video", "artist" => "Author")
      end

      it "extracts audio_sample_rate" do
        expect(probe_rich.audio_sample_rate).to eq(48_000)
      end

      it "extracts audio_channels" do
        expect(probe_rich.audio_channels).to eq(2)
      end

      it "extracts audio_channel_layout" do
        expect(probe_rich.audio_channel_layout).to eq("stereo")
      end

      it "extracts pixel_format" do
        expect(probe_rich.pixel_format).to eq("yuv420p")
      end

      it "extracts subtitle_streams" do
        expect(probe_rich.subtitle_streams.count).to eq(1)
        expect(probe_rich.subtitle_streams.first["codec_name"]).to eq("subrip")
      end

      it "extracts chapters" do
        expect(probe_rich.chapters.count).to eq(2)
        expect(probe_rich.chapters.first.dig("tags", "title")).to eq("Intro")
      end

      it "returns true for has_video?" do
        expect(probe_rich.has_video?).to be true
      end

      it "returns true for has_audio?" do
        expect(probe_rich.has_audio?).to be true
      end
    end

    context "with EXIF metadata" do
      let(:exif_json) do
        {
          "format" => {
            "tags" => {
              "com.apple.quicktime.location.ISO6709" => "+59.9311+030.3609/",
              "creation_time" => "2024-06-15T14:30:00.000000Z"
            }
          },
          "streams" => [
            {
              "codec_type" => "video",
              "width" => 3840,
              "height" => 2160,
              "tags" => {
                "rotate" => "0",
                "com.apple.quicktime.camera.framereadouttimeinmicroseconds" => "12500"
              }
            }
          ],
          "chapters" => []
        }.to_json
      end
      let(:probe_exif) { described_class.new(video_path) }

      before do
        allow(Open3).to receive(:capture3).and_return([exif_json, "", double(success?: true)])
      end

      it "returns EXIF tags from format-level tags" do
        expect(probe_exif.exif).to include("creation_time" => "2024-06-15T14:30:00.000000Z")
      end

      it "merges video stream tags into EXIF" do
        expect(probe_exif.exif).to include(
          "com.apple.quicktime.camera.framereadouttimeinmicroseconds" => "12500"
        )
      end

      it "returns empty hash when no tags" do
        allow(Open3).to receive(:capture3).and_return([
          {"streams" => [], "chapters" => []}.to_json,
          "",
          double(success?: true)
        ])
        probe = described_class.new(video_path)
        expect(probe.exif).to eq({})
      end
    end

    context "with audio-only file" do
      let(:audio_only_json) do
        {
          "streams" => [
            {"codec_type" => "audio", "sample_rate" => "44100", "channels" => 2,
             "channel_layout" => "stereo"}
          ],
          "chapters" => []
        }.to_json
      end
      let(:probe_audio) { described_class.new(video_path) }

      before do
        allow(Open3).to receive(:capture3).and_return([audio_only_json, "", double(success?: true)])
      end

      it "returns false for has_video?" do
        expect(probe_audio.has_video?).to be false
      end

      it "returns true for has_audio?" do
        expect(probe_audio.has_audio?).to be true
      end

      it "returns empty chapters" do
        expect(probe_audio.chapters).to eq([])
      end
    end
  end
end
