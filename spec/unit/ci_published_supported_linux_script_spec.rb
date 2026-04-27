require "spec_helper"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RSpec.describe "scripts/ci-published-supported-linux" do
  let(:repo_root) { Pathname.new(File.expand_path("../..", __dir__)) }
  let(:script_path) { repo_root.join("scripts/ci-published-supported-linux") }
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ci-published-supported-linux")) }
  let(:log_path) { tmpdir.join("verify.log") }
  let(:fake_verify_published_box) { tmpdir.join("verify-published-box") }

  before do
    write_executable(fake_verify_published_box, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf 'root=%s args=%s\\n' "${AVF_ACCEPTANCE_ROOT:-}" "$*" >> "#{log_path}"
    SH
  end

  after do
    FileUtils.remove_entry(tmpdir) if tmpdir.exist?
  end

  it "verifies the published ubuntu, almalinux, and rocky boxes in sequence" do
    stdout, stderr, status = run_script("sodini-io", "0.1.0")

    expect(status.success?).to be(true), stderr
    expect(stdout).to eq("")
    expect(log_path.read.lines(chomp: true)).to eq(
      [
        "root=#{tmpdir.join("matrix/ubuntu")} args=sodini-io/ubuntu-24.04-arm64 0.1.0",
        "root=#{tmpdir.join("matrix/almalinux")} args=sodini-io/almalinux-9-arm64 0.1.0",
        "root=#{tmpdir.join("matrix/rocky")} args=sodini-io/rocky-9-arm64 0.1.0"
      ]
    )
  end

  def run_script(*args)
    env = {
      "AVF_ACCEPTANCE_ROOT" => tmpdir.join("matrix").to_s,
      "AVF_VERIFY_PUBLISHED_BOX_COMMAND" => fake_verify_published_box.to_s
    }

    Open3.capture3(env, script_path.to_s, *args, chdir: repo_root.to_s)
  end

  def write_executable(path, body)
    path.write(body)
    path.chmod(0o755)
  end
end
