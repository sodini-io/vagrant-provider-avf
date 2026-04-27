require "spec_helper"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RSpec.describe "scripts/full-confidence" do
  let(:repo_root) { Pathname.new(File.expand_path("../..", __dir__)) }
  let(:script_path) { repo_root.join("scripts/full-confidence") }
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("full-confidence")) }
  let(:log_path) { tmpdir.join("commands.log") }
  let(:fake_release_confidence) { tmpdir.join("release-confidence") }
  let(:fake_post_release_confidence) { tmpdir.join("post-release-confidence") }

  before do
    write_executable(fake_release_confidence, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf 'release\\n' >> "#{log_path}"
    SH

    write_executable(fake_post_release_confidence, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf 'post %s\\n' "$*" >> "#{log_path}"
    SH
  end

  after do
    FileUtils.remove_entry(tmpdir) if tmpdir.exist?
  end

  it "runs local and published confidence in order" do
    stdout, stderr, status = run_script("sodini-io", "0.1.0")

    expect(status.success?).to be(true), stderr
    expect(stdout).to eq("")
    expect(log_path.read.lines(chomp: true)).to eq(
      [
        "release",
        "post sodini-io 0.1.0"
      ]
    )
  end

  it "fails clearly when org or version is missing" do
    _stdout, stderr, status = run_script

    expect(status.success?).to be(false)
    expect(stderr).to include("usage: full-confidence ORG_SLUG BOX_VERSION")
  end

  def run_script(*args)
    env = {
      "AVF_RELEASE_CONFIDENCE_COMMAND" => fake_release_confidence.to_s,
      "AVF_POST_RELEASE_CONFIDENCE_COMMAND" => fake_post_release_confidence.to_s,
      "PATH" => "#{tmpdir}:#{ENV.fetch("PATH")}"
    }

    Open3.capture3(env, "/bin/bash", script_path.to_s, *args, chdir: repo_root.to_s)
  end

  def write_executable(path, body)
    path.write(body)
    path.chmod(0o755)
  end
end
