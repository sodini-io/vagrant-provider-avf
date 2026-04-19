require "spec_helper"
require "fileutils"
require "pathname"
require "tmpdir"
require "test_machine"

RSpec.describe "linux feature surface" do
  class RecordingDriver
    attr_reader :start_calls

    def initialize(machine)
      @machine_metadata_store = VagrantPlugins::AVF::MachineMetadataStore.new(machine)
      @start_calls = []
    end

    def fetch(machine_id)
      @machine_metadata_store.fetch(machine_id: machine_id)
    end

    def read_state(machine_id)
      fetch(machine_id)&.state
    end

    def read_ssh_info(machine_id)
      metadata = fetch(machine_id)
      return unless metadata&.running?

      metadata.ssh_info
    end

    def create(machine_requirements, boot_config, machine_id: nil)
      metadata = VagrantPlugins::AVF::Model::MachineMetadata.stopped(
        machine_id || "avf-test-123",
        machine_requirements: machine_requirements,
        boot_config: boot_config
      )
      @machine_metadata_store.save(metadata)
      metadata
    end

    def start(machine_id, machine_requirements:, boot_config:, shared_directories: [])
      @start_calls << {
        machine_id: machine_id,
        machine_requirements: machine_requirements,
        boot_config: boot_config,
        shared_directories: shared_directories
      }
      metadata = VagrantPlugins::AVF::Model::MachineMetadata.running(
        machine_id,
        process_id: 4242,
        machine_requirements: machine_requirements,
        boot_config: boot_config
      )
      @machine_metadata_store.save(metadata)
      metadata
    end

    def stop(machine_id)
      metadata = fetch(machine_id)
      return unless metadata

      stopped_metadata = VagrantPlugins::AVF::Model::MachineMetadata.stopped(
        machine_id,
        machine_requirements: metadata.machine_requirements,
        boot_config: metadata.boot_config
      )
      @machine_metadata_store.save(stopped_metadata)
      stopped_metadata
    end

    def destroy(_machine_id)
      @machine_metadata_store.clear
    end
  end

  let(:data_dir) { Pathname.new(Dir.mktmpdir) }
  let(:root_path) { data_dir.join("project") }

  before do
    root_path.mkpath
    root_path.join("src").mkpath
    root_path.join("examples").mkpath
    data_dir.join("vmlinuz").write("kernel")
    data_dir.join("initrd.img").write("initrd")
    data_dir.join("source-disk.img").write("disk")
  end

  after do
    FileUtils.remove_entry(data_dir) if data_dir.exist?
  end

  def build_provider(provider_config:, synced_folders: {})
    machine = TestSupport::TestMachine.new(
      provider_config: provider_config,
      data_dir: data_dir,
      root_path: root_path,
      synced_folders: synced_folders
    )
    driver = RecordingDriver.new(machine)
    provider = VagrantPlugins::AVF::Provider.new(
      machine,
      driver_factory: ->(_current_machine) { driver }
    )
    machine.bind(provider)
    [machine, provider, driver]
  end

  it "passes the default and explicit avf synced folders through the provider boundary" do
    config = VagrantPlugins::AVF::Config.new.tap do |value|
      value.kernel_path = data_dir.join("vmlinuz").to_s
      value.initrd_path = data_dir.join("initrd.img").to_s
      value.disk_image_path = data_dir.join("source-disk.img").to_s
      value.finalize!
    end
    synced_folders = {
      "project-root" => { hostpath: ".", guestpath: "/vagrant" },
      "examples" => { hostpath: "examples", guestpath: "/home/vagrant/examples", type: :avf_virtiofs },
      "disabled" => { hostpath: "src", guestpath: "/srv/disabled", disabled: true },
      "rsync" => { hostpath: "src", guestpath: "/srv/rsync", type: :rsync }
    }
    machine, provider, driver = build_provider(provider_config: config, synced_folders: synced_folders)

    env = provider.action(:up).call(machine: machine)

    expect(machine.id).to eq("avf-test-123")
    expect(provider.state.id).to eq(:running)
    expect(env[:synced_folder_cleanup_called]).to be(true)
    expect(env[:synced_folders_called]).to be(true)
    expect(env[:wait_for_communicator_called]).to be(true)
    expect(driver.start_calls.size).to eq(1)

    shared_directories = driver.start_calls.first.fetch(:shared_directories)
    expect(shared_directories.map(&:guest_path)).to eq(["/vagrant", "/home/vagrant/examples"])
    expect(shared_directories.map(&:host_path)).to eq(
      [root_path.realpath.to_s, root_path.join("examples").realpath.to_s]
    )
  end

  it "treats disk-boot linux as the same accepted guest surface" do
    config = VagrantPlugins::AVF::Config.new.tap do |value|
      value.guest = :linux
      value.disk_image_path = data_dir.join("source-disk.img").to_s
      value.finalize!
    end
    machine, provider, driver = build_provider(provider_config: config)

    env = provider.action(:up).call(machine: machine)

    expect(machine.id).to eq("avf-test-123")
    expect(provider.state.id).to eq(:running)
    expect(env[:synced_folder_cleanup_called]).to be(true)
    expect(env[:synced_folders_called]).to be(true)
    expect(env[:wait_for_communicator_called]).to be(true)
    expect(driver.start_calls.first.fetch(:boot_config)).to be_linux_disk_boot
  end
end
