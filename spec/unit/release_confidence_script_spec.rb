require "spec_helper"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RSpec.describe "scripts/release-confidence" do
  let(:repo_root) { Pathname.new(File.expand_path("../..", __dir__)) }
  let(:script_path) { repo_root.join("scripts/release-confidence") }
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("release-confidence")) }
  let(:fake_bundle) { tmpdir.join("bundle") }
  let(:log_path) { tmpdir.join("commands.log") }
  let(:images_root) { tmpdir.join("images") }
  let(:boxes_root) { tmpdir.join("boxes") }
  let(:fake_build_box) { tmpdir.join("build-box") }
  let(:fake_build_almalinux_box) { tmpdir.join("build-almalinux-box") }
  let(:fake_build_rocky_box) { tmpdir.join("build-rocky-box") }
  let(:fake_ci_supported_linux) { tmpdir.join("ci-supported-linux") }

  before do
    boxes_root.mkpath

    write_executable(fake_bundle, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf 'bundle %s\\n' "$*" >> "#{log_path}"
    SH

    write_executable(fake_build_box, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      touch "#{boxes_root}/avf-ubuntu-24.04-arm64-0.1.0.box" "#{boxes_root}/avf-ubuntu-24.04-arm64-0.1.0.box.sha256"
      printf 'build-box\\n' >> "#{log_path}"
    SH

    write_executable(fake_build_almalinux_box, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      touch "#{boxes_root}/avf-almalinux-9-arm64-0.1.0.box" "#{boxes_root}/avf-almalinux-9-arm64-0.1.0.box.sha256"
      printf 'build-almalinux-box\\n' >> "#{log_path}"
    SH

    write_executable(fake_build_rocky_box, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      touch "#{boxes_root}/avf-rocky-9-arm64-0.1.0.box" "#{boxes_root}/avf-rocky-9-arm64-0.1.0.box.sha256"
      printf 'build-rocky-box\\n' >> "#{log_path}"
    SH

    write_executable(fake_ci_supported_linux, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf 'ci-supported-linux\\n' >> "#{log_path}"
    SH
  end

  after do
    FileUtils.remove_entry(tmpdir) if tmpdir.exist?
  end

  it "fails clearly when the local image artifacts are missing" do
    stdout, stderr, status = run_script

    expect(status.success?).to be(false)
    expect(stdout).to eq("")
    expect(stderr).to include("release-confidence requires local image artifacts before it can rebuild boxes:")
    expect(stderr).to include("#{images_root}/ubuntu-24.04-arm64/disk.img")
    expect(stderr).to include("scripts/post-release-confidence ORG_SLUG BOX_VERSION")
  end

  it "runs the local release gate once the required image artifacts exist" do
    write_image_artifact("ubuntu-24.04-arm64")
    write_image_artifact("almalinux-9-arm64")
    write_image_artifact("rocky-9-arm64")

    stdout, stderr, status = run_script

    expect(status.success?).to be(true), stderr
    expect(stdout).to eq("")
    expect(log_path.read.lines(chomp: true)).to eq(
      [
        "bundle exec rspec",
        "build-box",
        "build-almalinux-box",
        "build-rocky-box",
        "ci-supported-linux"
      ]
    )
  end

  def run_script
    env = {
      "PATH" => "#{tmpdir}:#{ENV.fetch("PATH")}",
      "AVF_RELEASE_CONFIDENCE_BOXES_DIR" => boxes_root.to_s,
      "AVF_RELEASE_CONFIDENCE_IMAGES_DIR" => images_root.to_s,
      "AVF_BUILD_BOX_COMMAND" => fake_build_box.to_s,
      "AVF_BUILD_ALMALINUX_BOX_COMMAND" => fake_build_almalinux_box.to_s,
      "AVF_BUILD_ROCKY_BOX_COMMAND" => fake_build_rocky_box.to_s,
      "AVF_CI_SUPPORTED_LINUX_COMMAND" => fake_ci_supported_linux.to_s
    }

    Open3.capture3(env, "/bin/bash", script_path.to_s, chdir: repo_root.to_s)
  end

  def write_image_artifact(name)
    path = images_root.join(name)
    path.mkpath
    path.join("disk.img").write("disk")
  end

  def write_executable(path, body)
    path.write(body)
    path.chmod(0o755)
  end
end
