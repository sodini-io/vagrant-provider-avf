require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe VagrantPlugins::AVF::SyncedFolder do
  class FakeCommunicator
    attr_reader :commands

    def initialize
      @commands = []
    end

    def execute(command, _opts = nil)
      @commands << [:execute, command]
      0
    end

    def sudo(command, _opts = nil)
      @commands << [:sudo, command]
      0
    end
  end

  let(:root_path) { Dir.mktmpdir }
  let(:host_share) { File.join(root_path, "share") }
  let(:boot_config) { instance_double(VagrantPlugins::AVF::Model::BootConfig, linux?: linux_guest) }
  let(:provider_config) { instance_double(VagrantPlugins::AVF::Config, boot_config: boot_config) }
  let(:communicate) { FakeCommunicator.new }
  let(:machine) do
    Struct.new(:provider_name, :provider_config, :communicate).new(:avf, provider_config, communicate)
  end
  let(:linux_guest) { true }
  let(:folders) do
    {
      "default" => {
        hostpath: host_share,
        guestpath: "/home/vagrant/workdir"
      }
    }
  end

  before do
    FileUtils.mkdir_p(host_share)
  end

  after do
    FileUtils.remove_entry(root_path) if File.exist?(root_path)
  end

  it "is usable for linux guests on the avf provider" do
    expect(described_class.new.usable?(machine)).to be(true)
  end

  it "rejects unsupported guests with a clear error when asked" do
    non_linux_machine = Struct.new(:provider_name, :provider_config).new(
      :avf,
      instance_double(VagrantPlugins::AVF::Config, boot_config: instance_double(VagrantPlugins::AVF::Model::BootConfig, linux?: false))
    )

    expect {
      described_class.new.usable?(non_linux_machine, true)
    }.to raise_error(VagrantPlugins::AVF::Errors::SyncedFoldersUnavailable, /guest=:linux/)
  end

  it "mounts the shared directory in the guest" do
    described_class.new.enable(machine, folders, {})

    expect(communicate.commands).to include(
      [:sudo, "mkdir -p /run/avf-shares"],
      [:sudo, "mountpoint -q /run/avf-shares || mount -t virtiofs avfshare /run/avf-shares"],
      [:sudo, "mkdir -p /home/vagrant/workdir"],
      [:sudo, "mountpoint -q /home/vagrant/workdir || mount --bind /run/avf-shares/#{VagrantPlugins::AVF::Model::SharedDirectory.name_for('default')} /home/vagrant/workdir"]
    )
  end
end
