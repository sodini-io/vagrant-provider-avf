require "spec_helper"

RSpec.describe VagrantPlugins::AVF::Config do
  def validation_errors(config)
    config.validate(nil).fetch("AVF provider", [])
  end

  it "defaults to a headless machine without sizing overrides" do
    config = described_class.new
    config.finalize!

    expect(config.cpus).to be_nil
    expect(config.memory_mb).to be_nil
    expect(config.disk_gb).to be_nil
    expect(config.headless).to be(true)
    expect(config.guest).to eq(:linux)
    expect(config.kernel_path).to be_nil
    expect(config.initrd_path).to be_nil
    expect(config.disk_image_path).to be_nil
  end

  it "accepts positive integer values and integer strings" do
    config = described_class.new
    config.cpus = "2"
    config.memory_mb = 2048
    config.disk_gb = "32"
    config.headless = false
    config.guest = :linux
    config.kernel_path = "/tmp/kernel"
    config.initrd_path = "/tmp/initrd"
    config.disk_image_path = "/tmp/disk.img"
    config.finalize!

    expect(config.validate(nil)).to eq({})
  end

  it "accepts a disk-only linux guest" do
    config = described_class.new
    config.guest = :linux
    config.disk_image_path = "/tmp/disk.img"
    config.finalize!

    expect(config.validate(nil)).to eq({})
  end

  it "rejects non-integer numeric values" do
    config = described_class.new
    config.cpus = 1.5
    config.memory_mb = "2.5"
    config.disk_gb = "abc"
    config.kernel_path = "/tmp/kernel"
    config.initrd_path = "/tmp/initrd"
    config.disk_image_path = "/tmp/disk.img"
    config.finalize!

    expect(validation_errors(config)).to contain_exactly(
      "cpus must be an integer",
      "memory_mb must be an integer",
      "disk_gb must be an integer"
    )
  end

  it "rejects zero and negative sizes" do
    config = described_class.new
    config.cpus = 0
    config.memory_mb = -1024
    config.disk_gb = "-1"
    config.kernel_path = "/tmp/kernel"
    config.initrd_path = "/tmp/initrd"
    config.disk_image_path = "/tmp/disk.img"
    config.finalize!

    expect(validation_errors(config)).to contain_exactly(
      "cpus must be greater than 0",
      "memory_mb must be greater than 0",
      "disk_gb must be greater than 0"
    )
  end

  it "rejects non-boolean headless values" do
    config = described_class.new
    config.kernel_path = "/tmp/kernel"
    config.initrd_path = "/tmp/initrd"
    config.disk_image_path = "/tmp/disk.img"
    config.headless = "yes"
    config.finalize!

    expect(validation_errors(config)).to eq(["headless must be true or false"])
  end

  it "rejects missing boot artifact paths" do
    config = described_class.new
    config.finalize!

    expect(validation_errors(config)).to contain_exactly("disk_image_path is required")
  end

  it "rejects relative boot artifact paths" do
    config = described_class.new
    config.kernel_path = "kernel"
    config.initrd_path = "/tmp/initrd"
    config.disk_image_path = "disk.img"
    config.finalize!

    expect(validation_errors(config)).to contain_exactly(
      "kernel_path must be an absolute path",
      "disk_image_path must be an absolute path"
    )
  end

  it "rejects unknown guest values" do
    config = described_class.new
    config.guest = :dragonfly
    config.disk_image_path = "/tmp/disk.img"
    config.finalize!

    expect(validation_errors(config)).to include("guest must be one of: linux")
  end
end
