# frozen_string_literal: true

require "spec_helper"

RSpec.describe FFmpegCore::Screenshot do
  let(:input_path) { fixture_path("sample_video.mp4") }
  let(:output_path) { tmp_path("thumb.jpg") }
  let(:options) { {} }
  let(:screenshot) { described_class.new(input_path, output_path, options) }

  describe "#extract" do
    before do
      allow(FileUtils).to receive(:mkdir_p)
      allow(Open3).to receive(:capture3).and_return(["", "", double(success?: true, exitstatus: 0)])
      allow(FFmpegCore.configuration).to receive(:ffmpeg_binary).and_return("ffmpeg")
    end

    it "builds basic command" do
      screenshot.extract
      expect(Open3).to have_received(:capture3).with(
        "ffmpeg",
        "-i", input_path.to_s,
        "-vframes", "1",
        "-q:v", "2",
        "-y",
        output_path.to_s
      )
    end

    context "with options" do
      let(:options) do
        {
          seek_time: 10,
          resolution: "300x200",
          quality: 5
        }
      end

      it "includes all options in correct order" do
        screenshot.extract
        expect(Open3).to have_received(:capture3).with(
          "ffmpeg",
          "-ss", "10",
          "-i", input_path.to_s,
          "-vframes", "1",
          "-s", "300x200",
          "-q:v", "5",
          "-y",
          output_path.to_s
        )
      end
    end
  end
end
