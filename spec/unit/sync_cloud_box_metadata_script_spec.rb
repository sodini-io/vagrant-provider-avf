require "spec_helper"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RSpec.describe "scripts/sync-cloud-box-metadata" do
  let(:repo_root) { Pathname.new(File.expand_path("../..", __dir__)) }
  let(:script_path) { repo_root.join("scripts/sync-cloud-box-metadata") }
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("sync-cloud-box-metadata")) }
  let(:vagrant_log) { tmpdir.join("vagrant.log") }
  let(:show_results) { tmpdir.join("show-results.txt") }
  let(:fake_vagrant) { tmpdir.join("vagrant") }

  before do
    show_results.write("missing\n")

    write_executable(fake_vagrant, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf '%s\\n' "$*" >> "#{vagrant_log}"

      if [[ "$1 $2 $3" == "cloud box show" ]]; then
        result="$(head -n 1 "#{show_results}" || true)"
        if [[ -s "#{show_results}" ]]; then
          tail -n +2 "#{show_results}" > "#{show_results}.next"
          mv "#{show_results}.next" "#{show_results}"
        fi
        [[ "${result}" == "exists" ]]
        exit
      fi
    SH
  end

  after do
    FileUtils.remove_entry(tmpdir) if tmpdir.exist?
  end

  it "creates all supported linux box entries for sodini-io by default" do
    stdout, stderr, status = run_script

    expect(status.success?).to be(true), stderr
    expect(vagrant_log.read).to include("cloud box create sodini-io/ubuntu-24.04-arm64")
    expect(vagrant_log.read).to include("https://github.com/sodini-io/vagrant-provider-avf")
    expect(vagrant_log.read).to include("cloud box create sodini-io/almalinux-9-arm64")
    expect(vagrant_log.read).to include("cloud box create sodini-io/rocky-9-arm64")
    expect(stdout).to include("created sodini-io/ubuntu-24.04-arm64 metadata")
  end

  it "updates an existing entry instead of creating it" do
    show_results.write("exists\n")

    stdout, stderr, status = run_script("--family", "ubuntu")

    expect(status.success?).to be(true), stderr
    expect(vagrant_log.read).to include("cloud box update sodini-io/ubuntu-24.04-arm64")
    expect(vagrant_log.read).not_to include("cloud box create sodini-io/ubuntu-24.04-arm64")
    expect(stdout).to include("updated sodini-io/ubuntu-24.04-arm64 metadata")
  end

  it "fails fast when auth is missing" do
    _stdout, stderr, status = run_script(auth: false)

    expect(status.success?).to be(false)
    expect(stderr).to include("cloud box auth is not configured")
  end

  it "rejects an unsupported family" do
    _stdout, stderr, status = run_script("--family", "oraclelinux")

    expect(status.success?).to be(false)
    expect(stderr).to include("unsupported family: oraclelinux")
  end

  def run_script(*args, auth: true)
    env = {
      "PATH" => "#{tmpdir}:#{ENV.fetch("PATH")}"
    }

    if auth
      env["HCP_CLIENT_ID"] = "test-client-id"
      env["HCP_CLIENT_SECRET"] = "test-client-secret"
    end

    Open3.capture3(env, script_path.to_s, *args, chdir: repo_root.to_s)
  end

  def write_executable(path, body)
    path.write(body)
    path.chmod(0o755)
  end
end
