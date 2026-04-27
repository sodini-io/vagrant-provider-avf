require "spec_helper"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RSpec.describe "scripts/verify-example-vagrantfile" do
  let(:repo_root) { Pathname.new(File.expand_path("../..", __dir__)) }
  let(:script_path) { repo_root.join("scripts/verify-example-vagrantfile") }
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("verify-example-vagrantfile")) }
  let(:log_path) { tmpdir.join("vagrant.log") }
  let(:state_path) { tmpdir.join("machine-state.txt") }
  let(:port_path) { tmpdir.join("ssh-port.txt") }
  let(:fake_vagrant) { tmpdir.join("vagrant") }
  let(:fake_xcrun) { tmpdir.join("xcrun") }

  before do
    port_path.write("2222\n")

    write_executable(fake_vagrant, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail

      log_file="#{log_path}"
      state_file="#{state_path}"
      port_file="#{port_path}"

      printf '%s\\n' "$*" >> "${log_file}"
      state="$(cat "${state_file}" 2>/dev/null || echo not_created)"

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
      esac

      case "$1" in
        validate)
          exit 0
          ;;
        status)
          if [[ "${2:-}" == "--machine-readable" ]]; then
            printf '1700000000,default,state,%s\\n' "${state}"
            exit 0
          fi
          exit 0
          ;;
        up)
          printf 'running\\n' > "${state_file}"
          exit 0
          ;;
        ssh-config)
          [[ "${state}" == "running" ]] || exit 1
          printf 'Host default\\n'
          printf '  HostName 127.0.0.1\\n'
          printf '  User vagrant\\n'
          printf '  Port %s\\n' "$(cat "${port_file}")"
          exit 0
          ;;
        ssh)
          [[ "${state}" == "running" ]] || exit 1
          command="${3:-}"

          case "${command}" in
            true)
              exit 0
              ;;
            "id -un && uname -m")
              printf 'vagrant\\naarch64\\n'
              exit 0
              ;;
            *"from-examples-share.txt"*)
              printf 'from-examples-share\\n' > "$PWD/examples/from-examples-share.txt"
              printf 'from-root-share\\n' > "$PWD/from-root-share.txt"
              exit 0
              ;;
            *"from-examples-share-restart.txt"*)
              printf 'from-examples-share-restart\\n' > "$PWD/examples/from-examples-share-restart.txt"
              printf 'from-root-share-restart\\n' > "$PWD/from-root-share-restart.txt"
              exit 0
              ;;
            *)
              exit 0
              ;;
          esac
          ;;
        halt)
          printf 'stopped\\n' > "${state_file}"
          exit 0
          ;;
        destroy)
          printf 'not_created\\n' > "${state_file}"
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
  end

  after do
    FileUtils.remove_entry(tmpdir) if tmpdir.exist?
  end

  it "verifies a minimal published example through the supported lifecycle" do
    example_dir = write_example("ubuntu-minimal", <<~RUBY)
      Vagrant.configure("2") do |config|
        config.vm.box = "avf/ubuntu-24.04-arm64"
        config.vm.box_check_update = false
      end
    RUBY

    stdout, stderr, status = run_script(example_dir.to_s)

    expect(status.success?).to be(true), stderr
    expect(log_path.read.lines(chomp: true)).to eq(
      [
        "plugin install vagrant-provider-avf",
        "plugin list",
        "box add sodini-io/ubuntu-24.04-arm64 --provider avf --box-version 0.1.0",
        "validate",
        "status --machine-readable",
        "up --provider=avf",
        "status --machine-readable",
        "ssh -c true",
        "ssh-config",
        "ssh -c id -un && uname -m",
        "halt",
        "status --machine-readable",
        "ssh -c true",
        "up --provider=avf",
        "status --machine-readable",
        "ssh -c true",
        "ssh-config",
        "ssh -c id -un && uname -m",
        "destroy -f",
        "status --machine-readable"
      ]
    )
    expect(stdout).to include("verified example plugin install provides vagrant-provider-avf")
    expect(stdout).to include("verified example Vagrantfile rewrites avf/ubuntu-24.04-arm64 to sodini-io/ubuntu-24.04-arm64")
    expect(stdout).to include("verified example box add fetches sodini-io/ubuntu-24.04-arm64 0.1.0")
    expect(stdout).to include("verified example vagrant validate accepts ubuntu-minimal")
    expect(stdout).to include("verified example vagrant destroy returns the machine to not_created")
  end

  it "passes through an explicit plugin version when requested" do
    example_dir = write_example("ubuntu-minimal", <<~RUBY)
      Vagrant.configure("2") do |config|
        config.vm.box = "avf/ubuntu-24.04-arm64"
      end
    RUBY

    _stdout, stderr, status = run_script(example_dir.to_s, plugin_version: "0.1.0")

    expect(status.success?).to be(true), stderr
    expect(log_path.read.lines(chomp: true)).to include(
      "plugin install vagrant-provider-avf --plugin-version 0.1.0"
    )
  end

  it "verifies the shared-folders example writes back through both guest mounts" do
    example_dir = write_example("shared-folders", <<~RUBY)
      Vagrant.configure("2") do |config|
        config.vm.box = "avf/ubuntu-24.04-arm64"
        config.vm.box_check_update = false
        config.vm.synced_folder ".", "/vagrant"
        config.vm.synced_folder "examples", "/home/vagrant/examples", type: :avf_virtiofs
      end
    RUBY

    stdout, stderr, status = run_script(example_dir.to_s)

    expect(status.success?).to be(true), stderr
    expect(stdout).to include("verified shared-folders example writes through both guest mounts")
    expect(stdout).to include("verified shared-folders example writes through both guest mounts after restart")
    expect(log_path.read).to include(
      "ssh -c test -f /vagrant/Vagrantfile && grep -q from-host /home/vagrant/examples/host.txt && printf 'from-examples-share\\n' > /home/vagrant/examples/from-examples-share.txt && printf 'from-root-share\\n' > /vagrant/from-root-share.txt"
    )
    expect(log_path.read).to include(
      "ssh -c printf 'from-examples-share-restart\\n' > /home/vagrant/examples/from-examples-share-restart.txt && printf 'from-root-share-restart\\n' > /vagrant/from-root-share-restart.txt"
    )
  end

  it "fails clearly when the example uses an unsupported box namespace" do
    example_dir = write_example("unsupported", <<~RUBY)
      Vagrant.configure("2") do |config|
        config.vm.box = "hashicorp/bionic64"
      end
    RUBY

    _stdout, stderr, status = run_script(example_dir.to_s)

    expect(status.success?).to be(false)
    expect(stderr).to include("example uses unsupported local box name: hashicorp/bionic64")
  end

  it "fails clearly when plugin install does not make the provider available" do
    example_dir = write_example("ubuntu-minimal", <<~RUBY)
      Vagrant.configure("2") do |config|
        config.vm.box = "avf/ubuntu-24.04-arm64"
      end
    RUBY

    _stdout, stderr, status = run_script(example_dir.to_s, plugin_list_output: "other-plugin (1.0.0)")

    expect(status.success?).to be(false)
    expect(stderr).to include("vagrant plugin install did not make vagrant-provider-avf available")
  end

  it "fails clearly when the example Vagrantfile is missing" do
    missing_dir = tmpdir.join("missing-example")
    missing_dir.mkpath

    _stdout, stderr, status = run_script(missing_dir.to_s)

    expect(status.success?).to be(false)
    expect(stderr).to include("example Vagrantfile does not exist")
  end

  it "fails clearly when vagrant is unavailable" do
    example_dir = write_example("ubuntu-minimal", <<~RUBY)
      Vagrant.configure("2") do |config|
        config.vm.box = "avf/ubuntu-24.04-arm64"
      end
    RUBY

    _stdout, stderr, status = run_script(example_dir.to_s, path: "/usr/bin:/bin")

    expect(status.success?).to be(false)
    expect(stderr).to include("vagrant is required for example verification")
  end

  it "fails clearly when xcrun is unavailable" do
    no_xcrun_dir = tmpdir.join("no-xcrun")
    build_shim_path(no_xcrun_dir, include_vagrant: true)

    example_dir = write_example("ubuntu-minimal", <<~RUBY)
      Vagrant.configure("2") do |config|
        config.vm.box = "avf/ubuntu-24.04-arm64"
      end
    RUBY

    _stdout, stderr, status = run_script(
      example_dir.to_s,
      path: no_xcrun_dir.to_s
    )

    expect(status.success?).to be(false)
    expect(stderr).to include("xcrun is required so the provider can build its local AVF helper")
  end

  def run_script(*args, plugin_version: nil, plugin_list_output: nil, path: nil)
    env = {
      "AVF_ACCEPTANCE_ROOT" => tmpdir.join("acceptance").to_s,
      "PATH" => path || "#{tmpdir}:#{ENV.fetch("PATH")}"
    }
    env["VERIFY_PUBLISHED_PLUGIN_VERSION"] = plugin_version if plugin_version
    env["FAKE_PLUGIN_LIST_OUTPUT"] = plugin_list_output if plugin_list_output

    Open3.capture3(env, "/bin/bash", script_path.to_s, *args, chdir: repo_root.to_s)
  end

  def write_example(name, vagrantfile)
    example_dir = tmpdir.join(name)
    example_dir.mkpath
    example_dir.join("Vagrantfile").write(vagrantfile)
    example_dir
  end

  def write_executable(path, body)
    path.write(body)
    path.chmod(0o755)
  end

  def build_shim_path(directory, include_vagrant:)
    directory.mkpath
    link_command("/usr/bin/basename", directory.join("basename"))
    link_command("/usr/bin/dirname", directory.join("dirname"))
    link_command("/usr/bin/mktemp", directory.join("mktemp"))
    link_command("/bin/mkdir", directory.join("mkdir"))
    link_command("/bin/rm", directory.join("rm"))
    link_command("/usr/bin/grep", directory.join("grep"))
    link_command("/bin/cat", directory.join("cat"))
    link_command("/bin/cp", directory.join("cp"))
    link_command("/usr/bin/ruby", directory.join("ruby"))
    link_command(fake_vagrant, directory.join("vagrant")) if include_vagrant
    directory.to_s
  end

  def link_command(source, target)
    FileUtils.ln_sf(source, target)
  end
end
