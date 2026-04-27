require "spec_helper"

RSpec.describe VagrantPlugins::AVF::SupportedLinuxBox do
  it "returns the ubuntu definition by family" do
    supported_box = described_class.fetch(:ubuntu)

    expect(supported_box.slug).to eq("ubuntu-24.04-arm64")
    expect(supported_box.local_box_name).to eq("avf/ubuntu-24.04-arm64")
    expect(supported_box.cloud_display_name).to eq("Ubuntu 24.04")
    expect(supported_box.default_release).to eq("24.04")
    expect(supported_box.default_disk_gb).to be_nil
    expect(supported_box.kernel_artifacts?).to be(true)
    expect(supported_box.release_env_name).to eq("UBUNTU_RELEASE")
    expect(supported_box.package_description("24.04.4")).to eq("Minimal Ubuntu 24.04.4 ARM64 base box for vagrant-provider-avf")
  end

  it "returns the almalinux definition by box name" do
    supported_box = described_class.for_box_name("sodini-io/almalinux-9-arm64")

    expect(supported_box.family).to eq("almalinux")
    expect(supported_box.cloud_display_name).to eq("AlmaLinux 9")
    expect(supported_box.default_disk_gb).to eq(12)
    expect(supported_box.kernel_artifacts?).to be(false)
    expect(supported_box.package_description("9.6")).to eq("Minimal AlmaLinux 9.6 ARM64 base box for vagrant-provider-avf")
  end

  it "returns the rocky definition by local box name" do
    supported_box = described_class.for_box_name("avf/rocky-9-arm64")

    expect(supported_box.family).to eq("rocky")
    expect(supported_box.cloud_display_name).to eq("Rocky Linux 9")
    expect(supported_box.default_disk_gb).to eq(12)
    expect(supported_box.release_env_name).to eq("ROCKY_RELEASE")
  end

  it "rejects unsupported families" do
    expect { described_class.fetch("oraclelinux") }
      .to raise_error(ArgumentError, /not a supported linux box family/)
  end

  it "returns nil for unsupported box names" do
    expect(described_class.for_box_name("sodini-io/oraclelinux-9-arm64")).to be_nil
  end
end
