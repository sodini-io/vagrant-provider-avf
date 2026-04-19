require "spec_helper"

RSpec.describe VagrantPlugins::AVF::DriverStartRequest do
  let(:data_dir) { Pathname.new(Dir.mktmpdir) }
  let(:paths) { VagrantPlugins::AVF::DriverPaths.new(data_dir) }
  let(:machine_requirements) do
    VagrantPlugins::AVF::Model::MachineRequirements.new(
      cpus: 2,
      memory_mb: 2048,
      disk_gb: 12,
      headless: true
    )
  end

  after do
    FileUtils.remove_entry(data_dir) if data_dir.exist?
  end

  it "builds a direct-boot linux request with shared directories" do
    boot_config = VagrantPlugins::AVF::Model::BootConfig.new(
      guest: :linux,
      kernel_path: "/box/vmlinuz",
      initrd_path: "/box/initrd.img",
      disk_image_path: "/box/disk.img"
    )
    shared_directories = [
      VagrantPlugins::AVF::Model::SharedDirectory.new(
        id: "vagrant",
        host_path: "/tmp/share",
        guest_path: "/vagrant"
      )
    ]

    request = described_class.new(
      machine_id: "avf-123",
      machine_requirements: machine_requirements,
      boot_config: boot_config,
      disk_path: data_dir.join("disk.img"),
      mac_address: "02:aa:bb:cc:dd:ee",
      shared_directories: shared_directories,
      seed_image_path: nil,
      efi_variable_store_path: nil,
      paths: paths
    ).to_h

    expect(request).to include(
      "guest" => "linux",
      "cpuCount" => 2,
      "memorySizeBytes" => 2048 * 1024 * 1024,
      "kernelPath" => "/box/vmlinuz",
      "initrdPath" => "/box/initrd.img",
      "diskImagePath" => data_dir.join("disk.img").to_s,
      "networkMacAddress" => "02:aa:bb:cc:dd:ee",
      "sharedDirectoryTag" => VagrantPlugins::AVF::Model::SharedDirectory::DEVICE_TAG,
      "seedImagePath" => nil,
      "seedImageReadOnly" => nil,
      "efiVariableStorePath" => nil,
      "consoleLogPath" => data_dir.join("console.log").to_s,
      "startedPath" => data_dir.join("avf-started.json").to_s,
      "errorPath" => data_dir.join("avf-error.txt").to_s,
      "commandLine" => described_class::DEFAULT_BOOT_COMMAND_LINE
    )
    expect(request.fetch("sharedDirectories")).to eq([shared_directories.first.to_h])
  end

  it "builds a disk-boot linux request with a read-only seed image" do
    boot_config = VagrantPlugins::AVF::Model::BootConfig.new(
      guest: :linux,
      kernel_path: nil,
      initrd_path: nil,
      disk_image_path: "/box/disk.img"
    )

    request = described_class.new(
      machine_id: "avf-efi-123",
      machine_requirements: machine_requirements,
      boot_config: boot_config,
      disk_path: data_dir.join("disk.img"),
      mac_address: "02:11:22:33:44:55",
      shared_directories: [],
      seed_image_path: data_dir.join("linux-seed.img"),
      efi_variable_store_path: data_dir.join("linux-efi.vars"),
      paths: paths
    ).to_h

    expect(request).to include(
      "sharedDirectoryTag" => nil,
      "sharedDirectories" => [],
      "seedImagePath" => data_dir.join("linux-seed.img").to_s,
      "seedImageReadOnly" => true,
      "efiVariableStorePath" => data_dir.join("linux-efi.vars").to_s,
      "commandLine" => nil
    )
  end
end
