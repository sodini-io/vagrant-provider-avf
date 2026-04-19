require "spec_helper"

RSpec.describe VagrantPlugins::AVF::CloudBoxMetadata do
  it "builds ubuntu cloud metadata with a repository reference" do
    metadata = described_class.new("sodini-io/ubuntu-24.04-arm64")

    expect(metadata.validate!).to eq(metadata)
    expect(metadata.short_description).to eq("Ubuntu 24.04 ARM64 for vagrant-provider-avf")
    expect(metadata.description).to include("Requires the vagrant-provider-avf plugin.")
    expect(metadata.description).to include("https://github.com/sodini-io/vagrant-provider-avf")
  end

  it "builds almalinux cloud metadata" do
    metadata = described_class.new("sodini-io/almalinux-9-arm64")

    expect(metadata.short_description).to eq("AlmaLinux 9 ARM64 for vagrant-provider-avf")
    expect(metadata.description).to include("Curated AlmaLinux 9 ARM64 base box")
  end

  it "builds rocky cloud metadata" do
    metadata = described_class.new("sodini-io/rocky-9-arm64")

    expect(metadata.short_description).to eq("Rocky Linux 9 ARM64 for vagrant-provider-avf")
    expect(metadata.description).to include("Curated Rocky Linux 9 ARM64 base box")
  end

  it "rejects an unsupported target" do
    metadata = described_class.new("sodini-io/oraclelinux-9-arm64")

    expect { metadata.validate! }.to raise_error(ArgumentError, /not a supported release target/)
  end
end
