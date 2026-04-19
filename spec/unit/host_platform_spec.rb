require "spec_helper"

RSpec.describe VagrantPlugins::AVF::HostPlatform do
  it "is supported on macOS arm64" do
    platform = described_class.new(os: "darwin23", cpu: "arm64")

    expect(platform).to be_supported
    expect(platform.description).to eq("darwin23/arm64")
  end

  it "is not supported on macOS x86_64" do
    platform = described_class.new(os: "darwin23", cpu: "x86_64")

    expect(platform).not_to be_supported
  end

  it "is not supported on non-macos hosts" do
    platform = described_class.new(os: "linux-gnu", cpu: "arm64")

    expect(platform).not_to be_supported
  end
end
