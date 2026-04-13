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

  describe "#cut" do
    let(:output_path) { tmp_path("cut_video.mp4") }

    after { FileUtils.rm_f(output_path) }

    it "cuts video with start_time and duration" do
      movie.cut(output_path, start_time: 0, duration: 1)

      expect(File.exist?(output_path)).to be true
      expect(File.size(output_path)).to be > 0
    end

    it "cuts video with start_time and end_time" do
      movie.cut(output_path, start_time: 0, end_time: 1)

      expect(File.exist?(output_path)).to be true
      expect(File.size(output_path)).to be > 0
    end

    it "returns output path" do
      result = movie.cut(output_path, start_time: 0, duration: 1)
      expect(result).to eq(output_path)
    end
  end

  describe "#extract_audio" do
    let(:av_path) { fixture_path("sample_video_with_audio.mp4") }
    let(:av_movie) { described_class.new(av_path) }
    let(:output_path) { tmp_path("audio.mp3") }

    after { FileUtils.rm_f(output_path) }

    it "extracts audio to file" do
      av_movie.extract_audio(output_path)

      expect(File.exist?(output_path)).to be true
      expect(File.size(output_path)).to be > 0
    end

    it "accepts codec option" do
      av_movie.extract_audio(output_path, codec: "libmp3lame")

      expect(File.exist?(output_path)).to be true
    end

    it "returns output path" do
      result = av_movie.extract_audio(output_path)
      expect(result).to eq(output_path)
    end
  end

  describe "#screenshots" do
    let(:output_dir) { tmp_path("screenshots") }

    after { FileUtils.rm_rf(output_dir) }

    it "extracts multiple screenshots" do
      paths = movie.screenshots(output_dir, count: 3)

      expect(paths.count).to eq(3)
      paths.each { |p| expect(File.exist?(p)).to be true }
    end

    it "returns array of file paths" do
      paths = movie.screenshots(output_dir, count: 2)
      expect(paths).to all(match(/\.jpg$/))
    end
  end
end
