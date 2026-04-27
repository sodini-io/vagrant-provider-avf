require "spec_helper"

RSpec.describe "Ubuntu image build files" do
  let(:repo_root) { Pathname.new(File.expand_path("../..", __dir__)) }
  let(:service_path) { repo_root.join("images/ubuntu/files/avf-ssh-hostkeys.service") }
  let(:build_script_path) { repo_root.join("images/ubuntu/build-image-in-container") }
  let(:configure_guest_path) { repo_root.join("images/ubuntu/configure-guest") }

  it "defines a first-boot SSH host key generator before ssh.service" do
    service = service_path.read

    expect(service).to include("Before=ssh.service")
    expect(service).to include("ExecStart=/usr/bin/ssh-keygen -A")
    expect(service).to include("WantedBy=ssh.service")
  end

  it "wires the host key generator into the Ubuntu image build and guest setup" do
    expect(build_script_path.read).to include("avf-ssh-hostkeys.service")
    expect(configure_guest_path.read).to include("enable_if_present avf-ssh-hostkeys.service")
    expect(configure_guest_path.read).to include("rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub")
  end
end
