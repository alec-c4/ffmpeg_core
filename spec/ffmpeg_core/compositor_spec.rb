# frozen_string_literal: true

require "spec_helper"

RSpec.describe FFmpegCore::Compositor do
  let(:input_paths) { [fixture_path("sample_video.mp4"), fixture_path("sample_video.mp4")] }
  let(:output_path) { tmp_path("output.mp4") }
  let(:options) { {} }
  let(:compositor) { described_class.new(input_paths, output_path, options) }

  describe ".new" do
    it "raises ArgumentError with empty inputs" do
      expect { described_class.new([], output_path) }.to raise_error(ArgumentError, /at least one/i)
    end
  end

  describe "#run" do
    before do
      allow(FileUtils).to receive(:mkdir_p)
      allow(Open3).to receive(:popen3).and_yield(nil, nil, StringIO.new, double(value: double(success?: true, exitstatus: 0)))
      allow(FFmpegCore.configuration).to receive(:ffmpeg_binary).and_return("ffmpeg")
    end

    it "raises InvalidInputError if a file does not exist" do
      compositor = described_class.new(["nonexistent.mp4", input_paths.first], output_path)
      expect { compositor.run }.to raise_error(FFmpegCore::InvalidInputError, /nonexistent\.mp4/)
    end

    it "builds command with multiple -i flags" do
      compositor.run
      expect(Open3).to have_received(:popen3).with(
        "ffmpeg",
        "-i", input_paths[0].to_s,
        "-i", input_paths[1].to_s,
        "-y",
        output_path.to_s
      )
    end

    context "with filter_complex and maps" do
      let(:options) do
        {
          filter_complex: "[0:v][1:v]overlay=0:0[v]",
          maps: ["[v]", "0:a"],
          video_codec: "libx264"
        }
      end

      it "includes filter_complex and map flags in correct order" do
        compositor.run
        expect(Open3).to have_received(:popen3).with(
          "ffmpeg",
          "-i", input_paths[0].to_s,
          "-i", input_paths[1].to_s,
          "-c:v", "libx264",
          "-filter_complex", "[0:v][1:v]overlay=0:0[v]",
          "-map", "[v]",
          "-map", "0:a",
          "-y",
          output_path.to_s
        )
      end
    end

    context "with array filter_complex" do
      let(:options) { {filter_complex: ["[0:v]scale=1280:720[v0]", "[v0][1:v]overlay[out]"]} }

      it "joins filter_complex array with semicolons" do
        compositor.run
        expect(Open3).to have_received(:popen3).with(
          "ffmpeg",
          "-i", input_paths[0].to_s,
          "-i", input_paths[1].to_s,
          "-filter_complex", "[0:v]scale=1280:720[v0];[v0][1:v]overlay[out]",
          "-y",
          output_path.to_s
        )
      end
    end

    context "with remote URLs" do
      let(:input_paths) { ["http://example.com/a.mp4", "http://example.com/b.mp4"] }

      it "does not check file existence for URLs" do
        expect { compositor.run }.not_to raise_error
      end
    end

    context "when transcoding fails" do
      before do
        allow(Open3).to receive(:popen3).and_yield(nil, nil, StringIO.new("Error details"), double(value: double(success?: false, exitstatus: 1)))
      end

      it "raises TranscodingError" do
        expect { compositor.run }.to raise_error(FFmpegCore::TranscodingError)
      end
    end
  end
end
