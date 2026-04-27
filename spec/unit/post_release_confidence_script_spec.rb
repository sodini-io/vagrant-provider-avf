require "spec_helper"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RSpec.describe "scripts/post-release-confidence" do
  let(:repo_root) { Pathname.new(File.expand_path("../..", __dir__)) }
  let(:script_path) { repo_root.join("scripts/post-release-confidence") }
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("post-release-confidence")) }
  let(:log_path) { tmpdir.join("bundle.log") }
  let(:fake_bundle) { tmpdir.join("bundle") }

  before do
    write_executable(fake_bundle, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      {
        printf 'args=%s\\n' "$*"
        printf 'published_acceptance=%s\\n' "${AVF_REAL_PUBLISHED_ACCEPTANCE:-}"
        printf 'box_org=%s\\n' "${AVF_BOX_ORG:-}"
        printf 'box_version=%s\\n' "${AVF_BOX_VERSION:-}"
      } >> "#{log_path}"
    SH
  end

  after do
    FileUtils.remove_entry(tmpdir) if tmpdir.exist?
  end

  it "runs the published acceptance spec with the requested org and version" do
    stdout, stderr, status = run_script("sodini-io", "0.1.0")

    expect(status.success?).to be(true), stderr
    expect(stdout).to eq("")
    expect(log_path.read.lines(chomp: true)).to eq(
      [
        "args=exec rspec spec/acceptance/published_linux_workflow_spec.rb spec/acceptance/published_examples_workflow_spec.rb",
        "published_acceptance=1",
        "box_org=sodini-io",
        "box_version=0.1.0"
      ]
    )
  end

  def run_script(*args)
    env = {
      "PATH" => "#{tmpdir}:#{ENV.fetch("PATH")}"
    }

    Open3.capture3(env, script_path.to_s, *args, chdir: repo_root.to_s)
  end

  def write_executable(path, body)
    path.write(body)
    path.chmod(0o755)
  end
end
