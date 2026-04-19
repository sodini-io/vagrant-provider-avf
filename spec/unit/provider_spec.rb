require "spec_helper"
require "fileutils"
require "pathname"
require "tmpdir"
require "test_machine"
require "fake_running_driver"

RSpec.describe VagrantPlugins::AVF::Provider do
  let(:supported_host_platform) { VagrantPlugins::AVF::HostPlatform.new(os: "darwin23", cpu: "arm64") }
  let(:unsupported_host_platform) { VagrantPlugins::AVF::HostPlatform.new(os: "linux-gnu", cpu: "x86_64") }

  let(:config) do
    VagrantPlugins::AVF::Config.new.tap do |value|
      value.kernel_path = data_dir.join("vmlinuz").to_s
      value.initrd_path = data_dir.join("initrd.img").to_s
      value.disk_image_path = data_dir.join("source-disk.img").to_s
      value.finalize!
    end
  end

  let(:data_dir) { Pathname.new(Dir.mktmpdir) }
  let(:machine) { TestSupport::TestMachine.new(provider_config: config, data_dir: data_dir) }
  let(:driver_factory) { ->(current_machine) { TestSupport::FakeRunningDriver.new(current_machine) } }
  let(:provider) { described_class.new(machine, driver_factory: driver_factory) }

  before do
    data_dir.join("vmlinuz").write("kernel")
    data_dir.join("initrd.img").write("initrd")
    data_dir.join("source-disk.img").write("disk")
    machine.bind(provider)
  end

  after do
    FileUtils.remove_entry(data_dir) if data_dir.exist?
  end

  it "exposes a read_state action" do
    expect(provider.action(:read_state)).to be_a(Vagrant::Action::Builder)
  end

  it "reports usable on supported hosts" do
    expect(described_class.usable?(false, host_platform: supported_host_platform)).to be(true)
  end

  it "reports not usable on unsupported hosts" do
    expect(described_class.usable?(false, host_platform: unsupported_host_platform)).to be(false)
  end

  it "raises a clear error on unsupported hosts when asked" do
    expect {
      described_class.usable?(true, host_platform: unsupported_host_platform)
    }.to raise_error(VagrantPlugins::AVF::Errors::UnsupportedHost, /macOS on Apple Silicon/)
  end

  it "exposes an up action" do
    expect(provider.action(:up)).to be_a(Vagrant::Action::Builder)
  end

  it "exposes a halt action" do
    expect(provider.action(:halt)).to be_a(Vagrant::Action::Builder)
  end

  it "exposes a destroy action" do
    expect(provider.action(:destroy)).to be_a(Vagrant::Action::Builder)
  end

  it "exposes an ssh_info action" do
    expect(provider.action(:ssh_info)).to be_a(Vagrant::Action::Builder)
  end

  it "exposes an ssh action" do
    expect(provider.action(:ssh)).to be_a(Vagrant::Action::Builder)
  end

  it "exposes an ssh_run action" do
    expect(provider.action(:ssh_run)).to be_a(Vagrant::Action::Builder)
  end

  it "returns not_created through the read_state action path before up runs" do
    expect(provider.state.id).to eq(:not_created)
  end

  it "creates a machine through the up action path" do
    env = provider.action(:up).call(machine: machine)

    expect(machine.id).to eq("avf-test-123")
    expect(provider.state.id).to eq(:running)
    expect(env[:synced_folder_cleanup_called]).to be(true)
    expect(env[:synced_folders_called]).to be(true)
    expect(env[:wait_for_communicator_called]).to be(true)
  end

  it "runs linux middleware for a disk-only linux guest" do
    disk_boot_config = described_guest_config(:linux)
    disk_boot_machine = TestSupport::TestMachine.new(provider_config: disk_boot_config, data_dir: data_dir)
    disk_boot_provider = described_class.new(
      disk_boot_machine,
      driver_factory: ->(current_machine) { TestSupport::FakeRunningDriver.new(current_machine) }
    )
    disk_boot_machine.bind(disk_boot_provider)

    env = disk_boot_provider.action(:up).call(machine: disk_boot_machine)

    expect(disk_boot_machine.id).to eq("avf-test-123")
    expect(disk_boot_provider.state.id).to eq(:running)
    expect(env[:synced_folder_cleanup_called]).to be(true)
    expect(env[:synced_folders_called]).to be(true)
    expect(env[:wait_for_communicator_called]).to be(true)
  end

  it "halts a running machine through the halt action path" do
    provider.action(:up).call(machine: machine)

    provider.action(:halt).call(machine: machine)

    expect(provider.state.id).to eq(:stopped)
  end

  it "destroys a machine through the provider action path" do
    provider.action(:up).call(machine: machine)

    provider.action(:destroy).call(machine: machine)

    expect(machine.id).to be_nil
    expect(provider.state.id).to eq(:not_created)
  end

  it "returns nil when the machine does not exist" do
    expect(provider.ssh_info).to be_nil
  end

  it "returns nil after up when no ssh info has been recorded" do
    provider.action(:up).call(machine: machine)

    expect(provider.ssh_info).to be_nil
  end

  it "returns stored ssh info for a running machine" do
    machine.id = "avf-123"
    VagrantPlugins::AVF::MachineMetadataStore.new(machine).save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-123",
        process_id: 4242,
        ssh_info: { host: "127.0.0.1", port: 2222, username: "vagrant" }
      )
    )

    expect(provider.ssh_info).to eq(host: "127.0.0.1", port: 2222, username: "vagrant")
  end

  it "returns nil after halt even when ssh info was previously available" do
    machine = TestSupport::TestMachine.new(provider_config: config, data_dir: data_dir)
    provider = described_class.new(
      machine,
      driver_factory: ->(current_machine) {
        TestSupport::FakeRunningDriver.new(
          current_machine,
          ssh_info: { host: "127.0.0.1", port: 2222, username: "vagrant" }
        )
      }
    )
    machine.bind(provider)

    provider.action(:up).call(machine: machine)

    expect(provider.ssh_info).to eq(host: "127.0.0.1", port: 2222, username: "vagrant")

    provider.action(:halt).call(machine: machine)

    expect(provider.state.id).to eq(:stopped)
    expect(provider.ssh_info).to be_nil
  end

  it "returns nil after destroy even when ssh info was previously available" do
    machine = TestSupport::TestMachine.new(provider_config: config, data_dir: data_dir)
    provider = described_class.new(
      machine,
      driver_factory: ->(current_machine) {
        TestSupport::FakeRunningDriver.new(
          current_machine,
          ssh_info: { host: "127.0.0.1", port: 2222, username: "vagrant" }
        )
      }
    )
    machine.bind(provider)

    provider.action(:up).call(machine: machine)

    expect(provider.ssh_info).to eq(host: "127.0.0.1", port: 2222, username: "vagrant")

    provider.action(:destroy).call(machine: machine)

    expect(machine.id).to be_nil
    expect(provider.state.id).to eq(:not_created)
    expect(provider.ssh_info).to be_nil
  end

  it "returns nil when no ssh info has been recorded" do
    VagrantPlugins::AVF::MachineMetadataStore.new(machine)
      .save(VagrantPlugins::AVF::Model::MachineMetadata.running("avf-123", process_id: 4242))

    machine.id = "avf-123"
    expect(provider.ssh_info).to be_nil
  end

  it "ignores stale ssh metadata when no machine id is stored" do
    VagrantPlugins::AVF::MachineMetadataStore.new(machine).save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-123",
        process_id: 4242,
        ssh_info: { host: "127.0.0.1", port: 2222, username: "vagrant" }
      )
    )

    expect(machine.id).to be_nil
    expect(provider.ssh_info).to be_nil
  end

  it "raises a clear error when read_state does not set machine_state" do
    machine = double("machine")
    allow(machine).to receive(:action).with(:read_state).and_return({})
    provider = described_class.new(machine)

    expect { provider.state }.to raise_error(VagrantPlugins::AVF::Errors::MissingMachineState)
  end

  def described_guest_config(guest)
    VagrantPlugins::AVF::Config.new.tap do |value|
      value.guest = guest
      value.disk_image_path = data_dir.join("source-disk.img").to_s
      value.finalize!
    end
  end
end
