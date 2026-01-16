# frozen_string_literal: true

require "spec_helper"

RSpec.describe FFmpegCore::Transcoder do
  let(:input_path) { fixture_path("sample_video.mp4") }
  let(:output_path) { tmp_path("output.mp4") }
  let(:options) { {} }
  let(:transcoder) { described_class.new(input_path, output_path, options) }

  describe "#run" do
    before do
      allow(FileUtils).to receive(:mkdir_p)
      allow(Open3).to receive(:popen3).and_yield(nil, nil, StringIO.new, double(value: double(success?: true, exitstatus: 0)))
      allow(FFmpegCore.configuration).to receive(:ffmpeg_binary).and_return("ffmpeg")
    end

    context "with remote url" do
      let(:transcoder) { described_class.new("http://example.com/video.mp4", output_path, options) }

      it "does not check for file existence" do
        transcoder.run
        expect(Open3).to have_received(:popen3).with(
          "ffmpeg",
          "-i", "http://example.com/video.mp4",
          "-y",
          output_path.to_s
        )
      end
    end

    context "when building command" do
      it "builds basic command" do
        transcoder.run
        expect(Open3).to have_received(:popen3).with(
          "ffmpeg",
          "-i", input_path.to_s,
          "-y",
          output_path.to_s
        )
      end
    end

    context "when options are provided" do
      let(:options) do
        {
          video_codec: "libx264",
          audio_codec: "aac",
          video_bitrate: "1000k",
          resolution: "1280x720",
          crop: { width: 100, height: 100, x: 10, y: 10 },
          video_filter: "scale=1280:-1",
          preset: "slow",
          crf: 23
        }
      end

      it "includes all options in command" do
        transcoder.run
        expect(Open3).to have_received(:popen3).with(
          "ffmpeg",
          "-i", input_path.to_s,
          "-c:v", "libx264",
          "-c:a", "aac",
          "-b:v", "1000k",
          "-s", "1280x720",
          "-vf", "scale=1280:-1,crop=100:100:10:10",
          "-preset", "slow",
          "-crf", "23",
          "-y",
          output_path.to_s
        )
      end
    end

    context "when reporting progress" do
      let(:stderr_output) do
        "frame=  100 ... time=00:00:05.00 ...\rframe=  200 ... time=00:00:10.00 ..."
      end

      let(:options) { {duration: 20.0} }

      before do
        allow(Open3).to receive(:popen3).and_yield(nil, nil, StringIO.new(stderr_output), double(value: double(success?: true)))
      end

      it "yields progress" do
        yielded_values = []
        transcoder.run do |progress|
          yielded_values << progress
        end

        # 5s / 20s = 0.25
        # 10s / 20s = 0.5
        expect(yielded_values).to include(0.25, 0.5)
      end
    end

    context "when handling errors" do
      before do
        allow(Open3).to receive(:popen3).and_yield(nil, nil, StringIO.new("Error message"), double(value: double(success?: false, exitstatus: 1)))
      end

      it "raises TranscodingError" do
        expect { transcoder.run }.to raise_error(FFmpegCore::TranscodingError)
      end
    end
  end
end
