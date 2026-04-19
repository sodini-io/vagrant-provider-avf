require "spec_helper"

RSpec.describe VagrantPlugins::AVF::Model::BootConfig do
  it "accepts absolute boot artifact paths for linux guests" do
    config = described_class.new(
      guest: :linux,
      kernel_path: "/tmp/kernel",
      initrd_path: "/tmp/initrd",
      disk_image_path: "/tmp/disk.img"
    )

    expect(config.errors).to eq([])
    expect(config.to_h).to eq(
      "guest" => "linux",
      "kernel_path" => "/tmp/kernel",
      "initrd_path" => "/tmp/initrd",
      "disk_image_path" => "/tmp/disk.img"
    )
    expect(config).to be_linux
    expect(config).to be_linux_kernel_boot
  end

  it "accepts a disk-only linux guest boot config" do
    config = described_class.new(
      guest: :linux,
      kernel_path: nil,
      initrd_path: nil,
      disk_image_path: "/tmp/disk.img"
    )

    expect(config.errors).to eq([])
    expect(config).to be_linux_disk_boot
  end

  it "rejects missing and relative paths for linux guests" do
    config = described_class.new(
      guest: :linux,
      kernel_path: nil,
      initrd_path: "initrd",
      disk_image_path: ""
    )

    expect(config.errors).to contain_exactly(
      "kernel_path is required",
      "initrd_path must be an absolute path",
      "disk_image_path is required"
    )
  end

  it "tracks changed fields including the guest type" do
    original = described_class.new(
      guest: :linux,
      kernel_path: "/tmp/kernel",
      initrd_path: "/tmp/initrd",
      disk_image_path: "/tmp/disk.img"
    )
    changed = described_class.new(
      guest: :dragonfly,
      kernel_path: nil,
      initrd_path: nil,
      disk_image_path: "/tmp/other-disk.img"
    )

    expect(changed.changed_fields(original)).to eq([:guest, :kernel_path, :initrd_path, :disk_image_path])
  end
end
