# frozen_string_literal: true

RSpec.describe FFmpegCore::Movie do
  let(:video_path) { fixture_path("sample_video.mp4") }
  let(:movie) { described_class.new(video_path) }

  describe "#initialize" do
    it "creates probe instance" do
      expect(movie.probe).to be_a(FFmpegCore::Probe)
    end
  end

  describe "metadata delegation" do
    it "delegates duration to probe" do
      expect(movie.duration).to eq(movie.probe.duration)
    end

    it "delegates dimensions to probe" do
      expect(movie.width).to eq(movie.probe.width)
      expect(movie.height).to eq(movie.probe.height)
    end
  end

  describe "#transcode" do
    let(:output_path) { tmp_path("transcoded_video.mp4") }

    after { FileUtils.rm_f(output_path) }

    it "transcodes video with options" do
      movie.transcode(output_path, {
        video_codec: "libx264",
        video_bitrate: "500k"
      })

      expect(File.exist?(output_path)).to be true
      expect(File.size(output_path)).to be > 0
    end
  end

  describe "#screenshot" do
    let(:output_path) { tmp_path("screenshot.jpg") }

    after { FileUtils.rm_f(output_path) }

    it "extracts screenshot" do
      movie.screenshot(output_path, {
        seek_time: 0,
        resolution: "320x240"
      })

      expect(File.exist?(output_path)).to be true
      expect(File.size(output_path)).to be > 0
    end
  end
end
