require "spec_helper"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

RSpec.describe "scripts/verify-vagrant-commands" do
  let(:repo_root) { Pathname.new(File.expand_path("../..", __dir__)) }
  let(:script_path) { repo_root.join("scripts/verify-vagrant-commands") }
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("verify-vagrant-commands")) }
  let(:work_dir) { tmpdir.join("work") }
  let(:box_path) { tmpdir.join("guest.box") }
  let(:log_path) { tmpdir.join("vagrant.log") }
  let(:state_path) { tmpdir.join("machine-state.txt") }
  let(:port_path) { tmpdir.join("ssh-port.txt") }
  let(:fake_vagrant) { tmpdir.join("vagrant") }

  before do
    box_path.write("box")
    port_path.write("2222\n")

    write_executable(fake_vagrant, <<~SH)
      #!/usr/bin/env bash
      set -euo pipefail

      state_file="#{state_path}"
      port_file="#{port_path}"
      log_file="#{log_path}"

      printf '%s\\n' "$*" >> "${log_file}"
      state="$(cat "${state_file}" 2>/dev/null || echo not_created)"

      case "$1" in
        box)
          [[ "${2:-}" == "add" ]] || exit 1
          exit 0
          ;;
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
            "test -s /etc/machine-id && find /etc/ssh -maxdepth 1 -name 'ssh_host_*_key' | grep -q .")
              exit 0
              ;;
            *"/home/vagrant/workdir/guest.txt"*)
              printf 'from-guest\\n' > "$PWD/host-share/guest.txt"
              exit 0
              ;;
            *"/home/vagrant/workdir/guest-restart.txt"*)
              printf 'from-guest-restart\\n' > "$PWD/host-share/guest-restart.txt"
              exit 0
              ;;
            *)
              printf 'unexpected ssh command: %s\\n' "${command}" >&2
              exit 1
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
  end

  after do
    FileUtils.remove_entry(tmpdir) if tmpdir.exist?
  end

  it "verifies the supported vagrant command surface and shared-folder writeback" do
    stdout, stderr, status = run_script(box_path.to_s)

    expect(status.success?).to be(true), stderr
    expect(log_path.read.lines(chomp: true)).to eq(
      [
        "box add --force --name avf/ubuntu-24.04-arm64 #{box_path}",
        "validate",
        "status --machine-readable",
        "up --provider=avf",
        "status --machine-readable",
        "ssh -c true",
        "ssh-config",
        "ssh -c id -un && uname -m",
        "ssh -c test -s /etc/machine-id && find /etc/ssh -maxdepth 1 -name 'ssh_host_*_key' | grep -q .",
        "ssh -c test -f /vagrant/Vagrantfile && grep -q from-host /home/vagrant/workdir/host.txt && printf 'from-guest\\n' > /home/vagrant/workdir/guest.txt",
        "halt",
        "status --machine-readable",
        "ssh -c true",
        "up --provider=avf",
        "status --machine-readable",
        "ssh -c true",
        "ssh-config",
        "ssh -c id -un && uname -m",
        "ssh -c grep -q from-host /home/vagrant/workdir/host.txt && printf 'from-guest-restart\\n' > /home/vagrant/workdir/guest-restart.txt",
        "destroy -f",
        "status --machine-readable"
      ]
    )
    expect(stdout).to include("verified vagrant box add stages avf/ubuntu-24.04-arm64 from a local box file")
    expect(stdout).to include("verified vagrant validate accepts the generated Vagrantfile")
    expect(stdout).to include("verified vagrant status before up reports not_created")
    expect(stdout).to include("verified vagrant up reaches running")
    expect(stdout).to include("verified vagrant ssh reaches the guest")
    expect(stdout).to include("verified vagrant ssh-config reports localhost forwarding for vagrant")
    expect(stdout).to include("verified vagrant halt reaches a stopped state")
    expect(stdout).to include("verified vagrant ssh fails after halt")
    expect(stdout).to include("verified vagrant destroy returns the machine to not_created")
    expect(work_dir.join("host-share/guest.txt").read).to eq("from-guest\n")
    expect(work_dir.join("host-share/guest-restart.txt").read).to eq("from-guest-restart\n")
  end

  it "fails clearly when the box file does not exist" do
    _stdout, stderr, status = run_script(tmpdir.join("missing.box").to_s)

    expect(status.success?).to be(false)
    expect(stderr).to include("box file does not exist")
  end

  it "fails clearly when vagrant is unavailable" do
    _stdout, stderr, status = run_script(box_path.to_s, path: "/usr/bin:/bin")

    expect(status.success?).to be(false)
    expect(stderr).to include("vagrant is required for command verification")
  end

  def run_script(*args, path: nil)
    env = {
      "PATH" => path || "#{tmpdir}:#{ENV.fetch("PATH")}",
      "VERIFY_VAGRANT_COMMANDS_WORK_DIR" => work_dir.to_s
    }

    Open3.capture3(env, "/bin/bash", script_path.to_s, *args, chdir: repo_root.to_s)
  end

  def write_executable(path, body)
    path.write(body)
    path.chmod(0o755)
  end
end
