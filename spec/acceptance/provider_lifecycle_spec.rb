require "spec_helper"
require "fileutils"
require "pathname"
require "tmpdir"
require "test_machine"
require "fake_running_driver"

RSpec.describe "provider lifecycle" do
  let(:config) do
    VagrantPlugins::AVF::Config.new.tap do |value|
      value.kernel_path = data_dir.join("vmlinuz").to_s
      value.initrd_path = data_dir.join("initrd.img").to_s
      value.disk_image_path = data_dir.join("source-disk.img").to_s
      value.finalize!
    end
  end

  let(:data_dir) { Pathname.new(Dir.mktmpdir) }

  before do
    data_dir.join("vmlinuz").write("kernel")
    data_dir.join("initrd.img").write("initrd")
    data_dir.join("source-disk.img").write("disk")
  end

  after do
    FileUtils.remove_entry(data_dir) if data_dir.exist?
  end

  def build_machine(id: nil, ssh_info: nil, provider_config: config)
    machine = TestSupport::TestMachine.new(
      provider_config: provider_config,
      data_dir: data_dir,
      id: id
    )
    provider = VagrantPlugins::AVF::Provider.new(
      machine,
      driver_factory: ->(current_machine) { TestSupport::FakeRunningDriver.new(current_machine, ssh_info: ssh_info) }
    )
    machine.bind(provider)

    [machine, provider]
  end

  def guest_config(guest)
    VagrantPlugins::AVF::Config.new.tap do |value|
      value.guest = guest
      value.disk_image_path = data_dir.join("source-disk.img").to_s
      value.finalize!
    end
  end

  it "starts as not_created and becomes running after up" do
    machine, provider = build_machine

    expect(provider.state.id).to eq(:not_created)

    provider.action(:up).call(machine: machine)

    reloaded_machine, reloaded_provider = build_machine(id: machine.id)

    expect(reloaded_machine.id).to eq(machine.id)
    expect(reloaded_provider.state.id).to eq(:running)
  end

  it "supports the disk-only linux guest through the provider boundary" do
    machine, provider = build_machine(provider_config: guest_config(:linux))

    expect(provider.state.id).to eq(:not_created)

    env = provider.action(:up).call(machine: machine)

    expect(machine.id).to eq("avf-test-123")
    expect(provider.state.id).to eq(:running)
    expect(env[:synced_folder_cleanup_called]).to be(true)
    expect(env[:synced_folders_called]).to be(true)
    expect(env[:wait_for_communicator_called]).to be(true)
  end

  it "persists stopped state across provider instances" do
    machine, provider = build_machine

    provider.action(:up).call(machine: machine)
    provider.action(:halt).call(machine: machine)

    reloaded_machine, reloaded_provider = build_machine(id: machine.id)

    expect(reloaded_machine.id).to eq(machine.id)
    expect(reloaded_provider.state.id).to eq(:stopped)
  end

  it "treats repeated halt as safe and idempotent" do
    machine, provider = build_machine

    provider.action(:up).call(machine: machine)
    provider.action(:halt).call(machine: machine)
    provider.action(:halt).call(machine: machine)

    reloaded_machine, reloaded_provider = build_machine(id: machine.id)

    expect(reloaded_machine.id).to eq(machine.id)
    expect(reloaded_provider.state.id).to eq(:stopped)
    expect(reloaded_provider.ssh_info).to be_nil
  end

  it "returns to not_created after destroy when reloaded" do
    machine, provider = build_machine

    provider.action(:up).call(machine: machine)
    provider.action(:destroy).call(machine: machine)

    reloaded_machine, reloaded_provider = build_machine

    expect(reloaded_machine.id).to be_nil
    expect(reloaded_provider.state.id).to eq(:not_created)
  end

  it "treats repeated destroy as safe and idempotent" do
    machine, provider = build_machine

    provider.action(:up).call(machine: machine)
    provider.action(:destroy).call(machine: machine)
    provider.action(:destroy).call(machine: machine)

    reloaded_machine, reloaded_provider = build_machine

    expect(reloaded_machine.id).to be_nil
    expect(reloaded_provider.state.id).to eq(:not_created)
    expect(reloaded_provider.ssh_info).to be_nil
  end

  it "refuses to reuse an existing machine when requirements changed" do
    machine, provider = build_machine
    provider.action(:up).call(machine: machine)

    changed_config = VagrantPlugins::AVF::Config.new.tap do |value|
      value.cpus = 4
      value.kernel_path = data_dir.join("vmlinuz").to_s
      value.initrd_path = data_dir.join("initrd.img").to_s
      value.disk_image_path = data_dir.join("source-disk.img").to_s
      value.finalize!
    end

    reloaded_machine = TestSupport::TestMachine.new(
      provider_config: changed_config,
      data_dir: data_dir,
      id: machine.id
    )
    reloaded_provider = VagrantPlugins::AVF::Provider.new(
      reloaded_machine,
      driver_factory: ->(current_machine) { TestSupport::FakeRunningDriver.new(current_machine) }
    )
    reloaded_machine.bind(reloaded_provider)

    expect { reloaded_provider.action(:up).call(machine: reloaded_machine) }
      .to raise_error(VagrantPlugins::AVF::Errors::MachineRequirementsChanged, /cpus/)
  end

  it "returns ssh info only when ssh metadata has been recorded" do
    machine, provider = build_machine

    expect(provider.ssh_info).to be_nil

    provider.action(:up).call(machine: machine)

    expect(provider.ssh_info).to be_nil

    reloaded_machine, reloaded_provider = build_machine(id: machine.id)
    VagrantPlugins::AVF::MachineMetadataStore.new(reloaded_machine).save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        machine.id,
        process_id: 4242,
        ssh_info: { host: "127.0.0.1", port: 2222, username: "vagrant" },
        machine_requirements: reloaded_machine.provider_config.machine_requirements,
        boot_config: reloaded_machine.provider_config.boot_config
      )
    )

    expect(reloaded_provider.ssh_info).to eq(
      host: "127.0.0.1",
      port: 2222,
      username: "vagrant"
    )
  end

  it "keeps the forwarded ssh port stable across halt and restart" do
    machine, provider = build_machine(ssh_info: { host: "127.0.0.1", port: 2222, username: "vagrant" })

    provider.action(:up).call(machine: machine)

    expect(provider.ssh_info).to eq(
      host: "127.0.0.1",
      port: 2222,
      username: "vagrant"
    )

    provider.action(:halt).call(machine: machine)

    expect(provider.ssh_info).to be_nil

    provider.action(:up).call(machine: machine)

    expect(provider.ssh_info).to eq(
      host: "127.0.0.1",
      port: 2222,
      username: "vagrant"
    )
  end
end
