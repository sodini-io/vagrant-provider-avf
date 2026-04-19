require "spec_helper"
require "pathname"
require "tmpdir"
require "fileutils"

RSpec.describe VagrantPlugins::AVF::SharedDirectories do
  let(:root_path) { Pathname.new(Dir.mktmpdir) }
  let(:provider_config) { instance_double(VagrantPlugins::AVF::Config, boot_config: boot_config) }
  let(:boot_config) { instance_double(VagrantPlugins::AVF::Model::BootConfig, linux?: true) }
  let(:synced_folders) { {} }
  let(:vm_config) { Struct.new(:synced_folders).new(synced_folders) }
  let(:machine) do
    Struct.new(:config, :env).new(
      Struct.new(:vm).new(vm_config),
      Struct.new(:root_path).new(root_path)
    )
  end

  after do
    FileUtils.remove_entry(root_path) if root_path.exist?
  end

  it "returns default and avf-specific synced folders as shared directories" do
    root_path.join("project").mkpath
    root_path.join("custom").mkpath
    allow(machine.config.vm).to receive(:synced_folders).and_return(
      "vagrant-root" => { hostpath: "project", guestpath: "/vagrant" },
      "custom" => { hostpath: "custom", guestpath: "/home/vagrant/workdir", type: :avf_virtiofs }
    )

    directories = described_class.for(machine)

    expect(directories.map(&:guest_path)).to eq(["/vagrant", "/home/vagrant/workdir"])
    expect(directories.map(&:host_path)).to eq(
      [root_path.join("project").realpath.to_s, root_path.join("custom").realpath.to_s]
    )
  end

  it "ignores disabled folders and folders with a different explicit type" do
    root_path.join("project").mkpath
    allow(machine.config.vm).to receive(:synced_folders).and_return(
      "disabled" => { hostpath: "project", guestpath: "/vagrant", disabled: true },
      "rsync" => { hostpath: "project", guestpath: "/srv/project", type: :rsync }
    )

    expect(described_class.for(machine)).to eq([])
  end
end
