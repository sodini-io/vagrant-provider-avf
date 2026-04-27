require "spec_helper"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RSpec.describe "scripts/ci-published-examples" do
  let(:repo_root) { Pathname.new(File.expand_path("../..", __dir__)) }
  let(:script_path) { repo_root.join("scripts/ci-published-examples") }
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ci-published-examples")) }
  let(:log_path) { tmpdir.join("verify.log") }
  let(:fake_verify_example) { tmpdir.join("verify-example-vagrantfile") }

  before do
    write_executable(fake_verify_example, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf 'root=%s args=%s\\n' "${AVF_ACCEPTANCE_ROOT:-}" "$*" >> "#{log_path}"
    SH
  end

  after do
    FileUtils.remove_entry(tmpdir) if tmpdir.exist?
  end

  it "verifies the published example Vagrantfiles in sequence" do
    stdout, stderr, status = run_script("sodini-io", "0.1.0")

    expect(status.success?).to be(true), stderr
    expect(stdout).to eq("")
    expect(log_path.read.lines(chomp: true)).to eq(
      [
        "root=#{tmpdir.join("matrix/ubuntu-minimal")} args=#{repo_root}/examples/ubuntu-minimal sodini-io 0.1.0",
        "root=#{tmpdir.join("matrix/almalinux")} args=#{repo_root}/examples/almalinux sodini-io 0.1.0",
        "root=#{tmpdir.join("matrix/rocky")} args=#{repo_root}/examples/rocky sodini-io 0.1.0",
        "root=#{tmpdir.join("matrix/shared-folders")} args=#{repo_root}/examples/shared-folders sodini-io 0.1.0"
      ]
    )
  end

  def run_script(*args)
    env = {
      "AVF_ACCEPTANCE_ROOT" => tmpdir.join("matrix").to_s,
      "AVF_VERIFY_EXAMPLE_VAGRANTFILE_COMMAND" => fake_verify_example.to_s
    }

    Open3.capture3(env, script_path.to_s, *args, chdir: repo_root.to_s)
  end

  def write_executable(path, body)
    path.write(body)
    path.chmod(0o755)
  end
end
