require "spec_helper"

RSpec.describe VagrantPlugins::AVF::Model::MachineMetadata do
  it "builds a running machine with symbolized ssh info keys" do
    metadata = described_class.running(
      "avf-123",
      process_id: 1234,
      ssh_info: { "host" => "127.0.0.1", "port" => 2222, "username" => "vagrant" },
      guest_ssh_info: { "host" => "192.168.64.2", "port" => 22, "username" => "vagrant" },
      ssh_port: 2222,
      ssh_forwarder_process_id: 5678
    )

    expect(metadata.machine_id).to eq("avf-123")
    expect(metadata.state).to eq(:running)
    expect(metadata.process_id).to eq(1234)
    expect(metadata.ssh_port).to eq(2222)
    expect(metadata.ssh_forwarder_process_id).to eq(5678)
    expect(metadata.ssh_info).to be_a(VagrantPlugins::AVF::Model::SshInfo)
    expect(metadata.guest_ssh_info).to be_a(VagrantPlugins::AVF::Model::SshInfo)
    expect(metadata.ssh_info.to_h).to eq(host: "127.0.0.1", port: 2222, username: "vagrant")
    expect(metadata.guest_ssh_info.to_h).to eq(host: "192.168.64.2", port: 22, username: "vagrant")
    expect(metadata).to be_running
  end

  it "round-trips through a hash payload" do
    metadata = described_class.from_h(
      "machine_id" => "avf-123",
      "state" => "stopped",
      "process_id" => nil,
      "ssh_info" => nil,
      "guest_ssh_info" => {
        "host" => "192.168.64.2",
        "port" => 22,
        "username" => "vagrant"
      },
      "machine_requirements" => {
        "cpus" => 2,
        "memory_mb" => 2048,
        "disk_gb" => 32,
        "headless" => false
      },
      "ssh_port" => 2222,
      "ssh_forwarder_process_id" => nil,
      "boot_config" => {
        "guest" => "linux",
        "kernel_path" => "/tmp/kernel",
        "initrd_path" => "/tmp/initrd",
        "disk_image_path" => "/tmp/disk.img"
      }
    )

    expect(metadata.to_h).to eq(
      "machine_id" => "avf-123",
      "state" => "stopped",
      "process_id" => nil,
      "ssh_info" => nil,
      "guest_ssh_info" => {
        "host" => "192.168.64.2",
        "port" => 22,
        "username" => "vagrant"
      },
      "machine_requirements" => {
        "cpus" => 2,
        "memory_mb" => 2048,
        "disk_gb" => 32,
        "headless" => false
      },
      "ssh_port" => 2222,
      "ssh_forwarder_process_id" => nil,
      "boot_config" => {
        "guest" => "linux",
        "kernel_path" => "/tmp/kernel",
        "initrd_path" => "/tmp/initrd",
        "disk_image_path" => "/tmp/disk.img"
      }
    )
    expect(metadata).not_to be_running
  end

  it "rejects unknown states" do
    expect {
      described_class.from_h("machine_id" => "avf-123", "state" => "broken", "ssh_info" => nil)
    }.to raise_error(ArgumentError, /state/)
  end

  it "requires a process id for running metadata" do
    expect {
      described_class.running("avf-123", process_id: nil)
    }.to raise_error(ArgumentError, /process_id/)
  end
end
