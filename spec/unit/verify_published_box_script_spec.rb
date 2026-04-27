require "spec_helper"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RSpec.describe "scripts/verify-published-box" do
  let(:repo_root) { Pathname.new(File.expand_path("../..", __dir__)) }
  let(:script_path) { repo_root.join("scripts/verify-published-box") }
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("verify-published-box")) }
  let(:log_path) { tmpdir.join("vagrant.log") }
  let(:verify_log_path) { tmpdir.join("verify.log") }
  let(:fake_vagrant) { tmpdir.join("vagrant") }
  let(:fake_xcrun) { tmpdir.join("xcrun") }
  let(:fake_verify_command) { tmpdir.join("verify-vagrant-commands") }

  before do
    write_executable(fake_vagrant, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      printf '%s\\n' "$*" >> "#{log_path}"

      case "$1 ${2:-}" in
        "plugin install")
          exit 0
          ;;
        "plugin list")
          printf '%s\\n' "${FAKE_PLUGIN_LIST_OUTPUT:-vagrant-provider-avf (0.1.0, local)}"
          exit 0
          ;;
        "box add")
          exit 0
          ;;
        *)
          printf 'unexpected vagrant command: %s\\n' "$*" >&2
          exit 1
          ;;
      esac
    SH

    write_executable(fake_xcrun, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
    SH

    write_executable(fake_verify_command, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail
      {
        printf 'args=%s\\n' "$*"
        printf 'box_name=%s\\n' "${BOX_NAME:-}"
        printf 'skip_box_add=%s\\n' "${VERIFY_VAGRANT_COMMANDS_SKIP_BOX_ADD:-}"
        printf 'disk_gb=%s\\n' "${DISK_GB:-}"
        printf 'work_dir=%s\\n' "${VERIFY_VAGRANT_COMMANDS_WORK_DIR:-}"
        printf 'vagrant_home=%s\\n' "${VAGRANT_HOME:-}"
      } >> "#{verify_log_path}"
    SH
  end

  after do
    FileUtils.remove_entry(tmpdir) if tmpdir.exist?
  end

  it "verifies the clean-home published install path before running the lifecycle verifier" do
    stdout, stderr, status = run_script("sodini-io/ubuntu-24.04-arm64", "0.1.0")

    expect(status.success?).to be(true), stderr
    expect(log_path.read.lines(chomp: true)).to eq(
      [
        "plugin install vagrant-provider-avf",
        "plugin list",
        "box add sodini-io/ubuntu-24.04-arm64 --provider avf --box-version 0.1.0"
      ]
    )
    expect(verify_log_path.read).to include("args=\n")
    expect(verify_log_path.read).to include("box_name=sodini-io/ubuntu-24.04-arm64\n")
    expect(verify_log_path.read).to include("skip_box_add=1\n")
    expect(verify_log_path.read).to include("disk_gb=8\n")
    expect(verify_log_path.read).to include("work_dir=#{tmpdir.join("acceptance/work")}\n")
    expect(verify_log_path.read).to include("vagrant_home=#{tmpdir.join("acceptance/home")}\n")
    expect(stdout).to include("verified vagrant plugin install provides vagrant-provider-avf")
    expect(stdout).to include("verified vagrant box add fetches sodini-io/ubuntu-24.04-arm64 0.1.0")
    expect(stdout).to include("verified published verification uses disk_gb 8 for sodini-io/ubuntu-24.04-arm64")
  end

  it "uses the larger disk floor for almalinux and rocky public boxes" do
    stdout, stderr, status = run_script("sodini-io/almalinux-9-arm64", "0.1.0")

    expect(status.success?).to be(true), stderr
    expect(log_path.read.lines(chomp: true)).to include(
      "box add sodini-io/almalinux-9-arm64 --provider avf --box-version 0.1.0"
    )
    expect(verify_log_path.read).to include("box_name=sodini-io/almalinux-9-arm64\n")
    expect(verify_log_path.read).to include("disk_gb=12\n")
    expect(stdout).to include("verified published verification uses disk_gb 12 for sodini-io/almalinux-9-arm64")
  end

  it "passes through an explicit plugin version when requested" do
    stdout, stderr, status = run_script(
      "sodini-io/ubuntu-24.04-arm64",
      "0.1.0",
      plugin_version: "0.1.0"
    )

    expect(status.success?).to be(true), stderr
    expect(log_path.read.lines(chomp: true)).to eq(
      [
        "plugin install vagrant-provider-avf --plugin-version 0.1.0",
        "plugin list",
        "box add sodini-io/ubuntu-24.04-arm64 --provider avf --box-version 0.1.0"
      ]
    )
    expect(stdout).to include("verified vagrant plugin install provides vagrant-provider-avf")
  end

  it "fails clearly when plugin install does not make the provider available" do
    _stdout, stderr, status = run_script(
      "sodini-io/ubuntu-24.04-arm64",
      "0.1.0",
      plugin_list_output: "other-plugin (1.0.0)"
    )

    expect(status.success?).to be(false)
    expect(stderr).to include("vagrant plugin install did not make vagrant-provider-avf available")
  end

  it "fails clearly when the box name is missing" do
    _stdout, stderr, status = run_script

    expect(status.success?).to be(false)
    expect(stderr).to include("usage: verify-published-box BOX_NAME [BOX_VERSION]")
  end

  it "fails clearly when vagrant is unavailable" do
    _stdout, stderr, status = run_script(
      "sodini-io/ubuntu-24.04-arm64",
      "0.1.0",
      path: "/usr/bin:/bin"
    )

    expect(status.success?).to be(false)
    expect(stderr).to include("vagrant is required for published box verification")
  end

  it "fails clearly when xcrun is unavailable" do
    no_xcrun_dir = tmpdir.join("no-xcrun")
    build_shim_path(no_xcrun_dir, include_vagrant: true)

    _stdout, stderr, status = run_script(
      "sodini-io/ubuntu-24.04-arm64",
      "0.1.0",
      path: no_xcrun_dir.to_s
    )

    expect(status.success?).to be(false)
    expect(stderr).to include("xcrun is required so the provider can build its local AVF helper")
  end

  def run_script(*args, plugin_version: nil, plugin_list_output: nil, path: nil)
    env = {
      "AVF_ACCEPTANCE_ROOT" => tmpdir.join("acceptance").to_s,
      "AVF_VERIFY_VAGRANT_COMMANDS_COMMAND" => fake_verify_command.to_s,
      "PATH" => path || "#{tmpdir}:#{ENV.fetch("PATH")}"
    }
    env["VERIFY_PUBLISHED_PLUGIN_VERSION"] = plugin_version if plugin_version
    env["FAKE_PLUGIN_LIST_OUTPUT"] = plugin_list_output if plugin_list_output

    Open3.capture3(env, "/bin/bash", script_path.to_s, *args, chdir: repo_root.to_s)
  end

  def write_executable(path, body)
    path.write(body)
    path.chmod(0o755)
  end

  def build_shim_path(directory, include_vagrant:)
    directory.mkpath
    link_command("/usr/bin/dirname", directory.join("dirname"))
    link_command("/usr/bin/mktemp", directory.join("mktemp"))
    link_command("/bin/mkdir", directory.join("mkdir"))
    link_command("/bin/rm", directory.join("rm"))
    link_command("/usr/bin/grep", directory.join("grep"))
    link_command("/bin/cat", directory.join("cat"))
    link_command("/usr/bin/ruby", directory.join("ruby"))
    link_command(fake_vagrant, directory.join("vagrant")) if include_vagrant
    directory.to_s
  end

  def link_command(source, target)
    FileUtils.ln_sf(source, target)
  end
end
