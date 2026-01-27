# frozen_string_literal: true

require "spec_helper"

RSpec.describe FFmpegCore::Transcoder do
  let(:input_path) { fixture_path("sample_video.mp4") }
  let(:output_path) { tmp_path("output.mp4") }
  let(:options) { {} }
  let(:transcoder) { described_class.new(input_path, output_path, options) }

  before do
    allow(FileUtils).to receive(:mkdir_p)
    allow(Open3).to receive(:popen3).and_yield(nil, nil, StringIO.new, double(value: double(success?: true, exitstatus: 0)))

    # Set the binary directly so the instance variable is updated for detect_encoders
    FFmpegCore.configuration.ffmpeg_binary = "ffmpeg"

    # Mock encoder detection - default to having none unless specified
    allow(Open3).to receive(:capture3).with("ffmpeg", "-encoders").and_return([
      "Encoders:\n V..... libx264\n",
      "",
      double(success?: true)
    ])

    # Reset cached encoders
    FFmpegCore.configuration.instance_variable_set(:@encoders, nil)
  end

  context "when h264_nvenc is available" do
    before do
      allow(Open3).to receive(:capture3).with("ffmpeg", "-encoders").and_return([
        "Encoders:\n V..... libx264\n V..... h264_nvenc\n",
        "",
        double(success?: true)
      ])
    end

    context "with hwaccel: :nvenc and default codec" do
      let(:options) { {hwaccel: :nvenc} }

      it "switches to h264_nvenc and injects global flags" do
        transcoder.run
        expect(Open3).to have_received(:popen3).with(
          "ffmpeg",
          "-hwaccel", "cuda",
          "-hwaccel_output_format", "cuda",
          "-i", input_path.to_s,
          "-c:v", "h264_nvenc",
          "-y",
          output_path.to_s
        )
      end
    end

    context "with hwaccel: :nvenc and explicit libx264" do
      let(:options) { {hwaccel: :nvenc, video_codec: "libx264"} }

      it "switches to h264_nvenc and injects global flags" do
        transcoder.run
        expect(Open3).to have_received(:popen3).with(
          "ffmpeg",
          "-hwaccel", "cuda",
          "-hwaccel_output_format", "cuda",
          "-i", input_path.to_s,
          "-c:v", "h264_nvenc",
          "-y",
          output_path.to_s
        )
      end
    end
  end

  context "when h264_nvenc is NOT available" do
    let(:options) { {hwaccel: :nvenc} }

    it "gracefully falls back to default codec" do
      transcoder.run
      expect(Open3).to have_received(:popen3).with(
        "ffmpeg",
        "-i", input_path.to_s,
        "-y",
        output_path.to_s
      )
    end
  end

  context "when hevc_nvenc is available" do
    before do
      allow(Open3).to receive(:capture3).with("ffmpeg", "-encoders").and_return([
        "Encoders:\n V..... libx264\n V..... hevc_nvenc\n",
        "",
        double(success?: true)
      ])
    end

    context "with hwaccel: :nvenc and libx265 codec" do
      let(:options) { {hwaccel: :nvenc, video_codec: "libx265"} }

      it "switches to hevc_nvenc and injects global flags" do
        transcoder.run
        expect(Open3).to have_received(:popen3).with(
          "ffmpeg",
          "-hwaccel", "cuda",
          "-hwaccel_output_format", "cuda",
          "-i", input_path.to_s,
          "-c:v", "hevc_nvenc",
          "-y",
          output_path.to_s
        )
      end
    end
  end

  context "with unknown hwaccel type" do
    let(:options) { {hwaccel: :future_tech} }

    it "ignores it" do
      transcoder.run
      expect(Open3).to have_received(:popen3).with(
        "ffmpeg",
        "-i", input_path.to_s,
        "-y",
        output_path.to_s
      )
    end
  end
end
