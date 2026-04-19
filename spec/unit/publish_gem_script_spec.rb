require "spec_helper"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RSpec.describe "scripts/publish-gem" do
  let(:repo_root) { Pathname.new(File.expand_path("../..", __dir__)) }
  let(:script_path) { repo_root.join("scripts/publish-gem") }
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("publish-gem")) }
  let(:build_log) { tmpdir.join("build.log") }
  let(:push_log) { tmpdir.join("push.log") }
  let(:confidence_log) { tmpdir.join("confidence.log") }
  let(:fake_gem) { tmpdir.join("gem") }
  let(:fake_release_confidence) { tmpdir.join("release-confidence") }
  let(:artifact_path) { repo_root.join("build/gems/vagrant-provider-avf-0.1.0.gem") }

  before do
    write_executable(fake_gem, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail

      case "$1" in
        build)
          printf '%s\\n' "$*" >> "#{build_log}"
          output_path="$4"
          mkdir -p "$(dirname "${output_path}")"
          touch "${output_path}"
          ;;
        push)
          printf '%s\\n' "$*" >> "#{push_log}"
          ;;
        *)
          echo "unexpected gem command: $*" >&2
          exit 1
          ;;
      esac
    SH

    write_executable(fake_release_confidence, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf 'ran\\n' >> "#{confidence_log}"
    SH
  end

  after do
    artifact_path.delete if artifact_path.exist?
    FileUtils.remove_entry(tmpdir) if tmpdir.exist?
  end

  it "runs release confidence, builds the gem, and pushes it with RubyGems auth" do
    stdout, stderr, status = run_script

    expect(status.success?).to be(true), stderr
    expect(confidence_log.read).to eq("ran\n")
    expect(build_log.read).to include("build vagrant-provider-avf.gemspec --output #{artifact_path}")
    expect(push_log.read).to include("push #{artifact_path}")
    expect(stdout).to include("published #{artifact_path.basename} to RubyGems.org")
  end

  it "can skip the release confidence gate" do
    _stdout, stderr, status = run_script("--skip-confidence")

    expect(status.success?).to be(true), stderr
    expect(confidence_log.exist?).to be(false)
  end

  it "fails fast when RubyGems auth is not configured" do
    _stdout, stderr, status = run_script(auth: false)

    expect(status.success?).to be(false)
    expect(stderr).to include("RubyGems auth is not configured")
  end

  def run_script(*args, auth: true)
    env = {
      "AVF_RELEASE_CONFIDENCE_COMMAND" => fake_release_confidence.to_s,
      "PATH" => "#{tmpdir}:#{ENV.fetch("PATH")}"
    }
    env["GEM_HOST_API_KEY"] = "test-rubygems-key" if auth

    Open3.capture3(env, script_path.to_s, *args, chdir: repo_root.to_s)
  end

  def write_executable(path, body)
    path.write(body)
    path.chmod(0o755)
  end
end
