require "spec_helper"

RSpec.describe VagrantPlugins::AVF::Plugin do
  it "registers provider-specific config for avf" do
    expect(described_class.registered_configs[["avf", :provider]]).to be(VagrantPlugins::AVF::Config)
  end

  it "registers the avf provider" do
    expect(described_class.registered_providers[:avf]).to be(VagrantPlugins::AVF::Provider)
  end

  it "registers the avf virtiofs synced folder" do
    expect(described_class.registered_synced_folders[:avf_virtiofs]).to be(VagrantPlugins::AVF::SyncedFolder)
  end
end
