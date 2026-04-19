require "spec_helper"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RSpec.describe "scripts/publish-supported-linux" do
  let(:repo_root) { Pathname.new(File.expand_path("../..", __dir__)) }
  let(:script_path) { repo_root.join("scripts/publish-supported-linux") }
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("publish-supported-linux")) }
  let(:publish_log) { tmpdir.join("publish.log") }
  let(:confidence_log) { tmpdir.join("confidence.log") }
  let(:curl_log) { tmpdir.join("curl.log") }
  let(:curl_body) { tmpdir.join("curl.json") }
  let(:sync_log) { tmpdir.join("sync.log") }
  let(:fake_publish_box) { tmpdir.join("publish-box") }
  let(:fake_release_confidence) { tmpdir.join("release-confidence") }
  let(:fake_curl) { tmpdir.join("curl") }
  let(:fake_sync_cloud_box_metadata) { tmpdir.join("sync-cloud-box-metadata") }

  before do
    write_executable(fake_publish_box, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf '%s\\n' "$*" >> "#{publish_log}"
    SH

    write_executable(fake_release_confidence, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf 'ran\\n' >> "#{confidence_log}"
    SH

    write_executable(fake_curl, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf '%s\\n' "$*" >> "#{curl_log}"
      cat "#{curl_body}"
    SH

    write_executable(fake_sync_cloud_box_metadata, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf '%s\\n' "$*" >> "#{sync_log}"
    SH
  end

  after do
    FileUtils.remove_entry(tmpdir) if tmpdir.exist?
  end

  it "publishes all supported linux boxes for sodini-io by default" do
    stdout, stderr, status = run_script("0.1.0")

    expect(status.success?).to be(true), stderr
    expect(confidence_log.read).to eq("ran\n")
    expect(sync_log.read.lines(chomp: true)).to eq(
      [
        "--org sodini-io --family ubuntu",
        "--org sodini-io --family almalinux",
        "--org sodini-io --family rocky"
      ]
    )
    expect(publish_log.read.lines(chomp: true)).to eq(
      [
        "sodini-io/ubuntu-24.04-arm64 0.1.0 #{repo_root}/build/boxes/avf-ubuntu-24.04-arm64-0.1.0.box",
        "sodini-io/almalinux-9-arm64 0.1.0 #{repo_root}/build/boxes/avf-almalinux-9-arm64-0.1.0.box",
        "sodini-io/rocky-9-arm64 0.1.0 #{repo_root}/build/boxes/avf-rocky-9-arm64-0.1.0.box"
      ]
    )
    expect(curl_log.exist?).to be(false)
    expect(stdout).to include("staged sodini-io/ubuntu-24.04-arm64 as an unreleased version")
  end

  it "can release one supported family and verify the registry api" do
    curl_body.write(
      <<~JSON
        {"name":"sodini-io/ubuntu-24.04-arm64","versions":[{"version":"0.1.0","providers":[{"name":"avf"}]}]}
      JSON
    )

    stdout, stderr, status = run_script("0.1.0", "--family", "ubuntu", "--release", "--skip-confidence")

    expect(status.success?).to be(true), stderr
    expect(sync_log.read.lines(chomp: true)).to eq(
      [
        "--org sodini-io --family ubuntu"
      ]
    )
    expect(publish_log.read.lines(chomp: true)).to eq(
      [
        "sodini-io/ubuntu-24.04-arm64 0.1.0 #{repo_root}/build/boxes/avf-ubuntu-24.04-arm64-0.1.0.box --release"
      ]
    )
    expect(curl_log.read).to include("https://vagrantcloud.com/api/v2/vagrant/sodini-io/ubuntu-24.04-arm64")
    expect(stdout).to include("released sodini-io/ubuntu-24.04-arm64 0.1.0 is visible in the registry api")
  end

  it "fails fast when publish auth is not configured" do
    _stdout, stderr, status = run_script("0.1.0", auth: false)

    expect(status.success?).to be(false)
    expect(stderr).to include("publish auth is not configured")
  end

  it "rejects an unknown supported family" do
    _stdout, stderr, status = run_script("0.1.0", "--family", "oraclelinux", "--skip-confidence")

    expect(status.success?).to be(false)
    expect(stderr).to include("unsupported family: oraclelinux")
  end

  def run_script(*args, auth: true)
    env = {
      "AVF_PUBLISH_BOX_COMMAND" => fake_publish_box.to_s,
      "AVF_RELEASE_CONFIDENCE_COMMAND" => fake_release_confidence.to_s,
      "AVF_SYNC_CLOUD_BOX_METADATA_COMMAND" => fake_sync_cloud_box_metadata.to_s,
      "PATH" => "#{tmpdir}:#{ENV.fetch("PATH")}",
      "VAGRANT_CLOUD_TOKEN" => nil,
      "HCP_CLIENT_ID" => nil,
      "HCP_CLIENT_SECRET" => nil
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
