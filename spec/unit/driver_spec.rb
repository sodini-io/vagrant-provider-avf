require "spec_helper"
require "digest"
require "fileutils"
require "pathname"
require "tmpdir"

RSpec.describe VagrantPlugins::AVF::Driver do
  class FakeProcessControl
    attr_reader :commands, :stopped_processes, :request

    def initialize(alive_processes: nil, on_spawn: nil, on_stop: nil)
      @alive_processes = alive_processes || {}
      @on_spawn = on_spawn
      @on_stop = on_stop
      @commands = []
      @stopped_processes = []
    end

    def spawn(command, out:, err:)
      @commands << { command: command, out: out, err: err }
      process_id = 4321
      @alive_processes[process_id] = true
      @on_spawn&.call(command, process_id)
      process_id
    end

    def alive?(process_id)
      @alive_processes.fetch(process_id, false)
    end

    def stop(process_id, timeout:)
      @stopped_processes << { process_id: process_id, timeout: timeout }
      @on_stop&.call(process_id, timeout)
      @alive_processes[process_id] = false
    end
  end

  let(:data_dir) { Pathname.new(Dir.mktmpdir) }
  let(:machine) { Struct.new(:data_dir).new(data_dir) }
  let(:machine_metadata_store) { VagrantPlugins::AVF::MachineMetadataStore.new(machine) }
  let(:machine_requirements) do
    VagrantPlugins::AVF::Model::MachineRequirements.new(
      cpus: 2,
      memory_mb: 2048,
      disk_gb: 1,
      headless: true
    )
  end
  let(:boot_config) do
    VagrantPlugins::AVF::Model::BootConfig.new(
      guest: :linux,
      kernel_path: data_dir.join("vmlinuz").to_s,
      initrd_path: data_dir.join("initrd.img").to_s,
      disk_image_path: data_dir.join("source-disk.img").to_s
    )
  end
  let(:linux_efi_boot_config) do
    VagrantPlugins::AVF::Model::BootConfig.new(
      guest: :linux,
      kernel_path: nil,
      initrd_path: nil,
      disk_image_path: data_dir.join("source-disk.img").to_s
    )
  end
  let(:port_allocator) { instance_double(VagrantPlugins::AVF::PortAllocator, allocate: 2222) }
  let(:dhcp_leases) { instance_double(VagrantPlugins::AVF::DhcpLeases, ip_address_for: nil) }
  let(:linux_cloud_init_seed) do
    instance_double(
      VagrantPlugins::AVF::LinuxCloudInitSeed,
      write: data_dir.join("linux-seed.img"),
      path: data_dir.join("linux-seed.img")
    )
  end
  let(:ssh_forwarder) do
    instance_double(
      VagrantPlugins::AVF::SshForwarder,
      start: 5678,
      stop: nil,
      alive?: false,
      cleanup_files: nil
    )
  end
  let(:shared_directories) do
    [
      VagrantPlugins::AVF::Model::SharedDirectory.new(
        id: "vagrant",
        host_path: data_dir.to_s,
        guest_path: "/vagrant"
      )
    ]
  end

  def build_driver(**options)
    described_class.new(
      {
        machine_metadata_store: machine_metadata_store,
        machine_data_dir: data_dir,
        dhcp_leases: dhcp_leases,
        linux_cloud_init_seed: linux_cloud_init_seed,
        port_allocator: port_allocator,
        ssh_forwarder: ssh_forwarder
      }.merge(options)
    )
  end

  before do
    data_dir.join("vmlinuz").write("kernel")
    data_dir.join("initrd.img").write("initrd")
    data_dir.join("source-disk.img").write("disk")
  end

  after do
    FileUtils.remove_entry(data_dir) if data_dir.exist?
  end

  it "creates stopped metadata with a stable provider-scoped machine id" do
    driver = build_driver(machine_id_generator: -> { "1234" })

    metadata = driver.create(machine_requirements, boot_config)

    expect(metadata.machine_id).to eq("avf-1234")
    expect(metadata.state).to eq(:stopped)
    expect(metadata.ssh_port).to eq(2222)
    expect(metadata.machine_requirements.to_h).to eq(machine_requirements.to_h)
    expect(metadata.boot_config.to_h).to eq(boot_config.to_h)
    expect(machine_metadata_store.fetch(machine_id: "avf-1234").state).to eq(:stopped)
  end

  it "starts a linux machine by writing a request and persisting running metadata" do
    process_control = FakeProcessControl.new(
      on_spawn: lambda do |command, process_id|
        request_path = Pathname.new(command.last)
        request = JSON.parse(request_path.read)
        started_path = Pathname.new(request.fetch("startedPath"))
        started_path.write(JSON.dump("process_id" => process_id))
      end
    )
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.stopped(
        "avf-123",
        machine_requirements: machine_requirements,
        boot_config: boot_config,
        ssh_port: 2222
      )
    )
    driver = build_driver(
      process_control: process_control,
      helper_installer: -> { data_dir.join("fake-helper") }
    )

    metadata = driver.start(
      "avf-123",
      machine_requirements: machine_requirements,
      boot_config: boot_config,
      shared_directories: shared_directories
    )

    request = JSON.parse(data_dir.join("avf-start-request.json").read)
    expect(request.fetch("guest")).to eq("linux")
    expect(request.fetch("cpuCount")).to eq(2)
    expect(request.fetch("memorySizeBytes")).to eq(2048 * 1024 * 1024)
    expect(request.fetch("kernelPath")).to eq(boot_config.kernel_path)
    expect(request.fetch("initrdPath")).to eq(boot_config.initrd_path)
    expect(request.fetch("diskImagePath")).to eq(data_dir.join("disk.img").to_s)
    expect(request.fetch("networkMacAddress")).to eq("02:#{Digest::SHA256.hexdigest("avf-123")[0, 10].scan(/../).join(':')}")
    expect(request.fetch("sharedDirectoryTag")).to eq(VagrantPlugins::AVF::Model::SharedDirectory::DEVICE_TAG)
    expect(request.fetch("sharedDirectories")).to eq(
      [
        {
          "hostPath" => data_dir.to_s,
          "name" => VagrantPlugins::AVF::Model::SharedDirectory.name_for("vagrant"),
          "readOnly" => false
        }
      ]
    )
    expect(request.fetch("seedImagePath")).to be_nil
    expect(request.fetch("commandLine")).to eq("console=hvc0 root=LABEL=avf-root rw rootwait rootfstype=ext4")
    expect(data_dir.join("disk.img").size).to eq(1 * 1024 * 1024 * 1024)
    expect(metadata.state).to eq(:running)
    expect(metadata.process_id).to eq(4321)
    expect(metadata.ssh_port).to eq(2222)
    expect(machine_metadata_store.fetch(machine_id: "avf-123").state).to eq(:running)
  end

  it "starts a disk-only linux machine with an efi variable store" do
    process_control = FakeProcessControl.new(
      on_spawn: lambda do |command, process_id|
        request = JSON.parse(Pathname.new(command.last).read)
        Pathname.new(request.fetch("startedPath")).write(JSON.dump("process_id" => process_id))
      end
    )
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.stopped(
        "avf-linux-efi-123",
        machine_requirements: machine_requirements,
        boot_config: linux_efi_boot_config,
        ssh_port: 2222
      )
    )
    driver = build_driver(
      process_control: process_control,
      helper_installer: -> { data_dir.join("fake-helper") }
    )

    metadata = driver.start(
      "avf-linux-efi-123",
      machine_requirements: machine_requirements,
      boot_config: linux_efi_boot_config,
      shared_directories: []
    )

    request = JSON.parse(data_dir.join("avf-start-request.json").read)
    expect(request.fetch("guest")).to eq("linux")
    expect(request.fetch("kernelPath")).to be_nil
    expect(request.fetch("initrdPath")).to be_nil
    expect(request.fetch("seedImagePath")).to eq(data_dir.join("linux-seed.img").to_s)
    expect(request.fetch("seedImageReadOnly")).to eq(true)
    expect(request.fetch("efiVariableStorePath")).to eq(data_dir.join("linux-efi.vars").to_s)
    expect(linux_cloud_init_seed).to have_received(:write).with(
      machine_id: "avf-linux-efi-123",
      mac_address: "02:#{Digest::SHA256.hexdigest("avf-linux-efi-123")[0, 10].scan(/../).join(':')}"
    )
    expect(metadata.boot_config.guest).to eq(:linux)
  end

  it "preserves the last guest ssh address when a machine restarts" do
    process_control = FakeProcessControl.new(
      on_spawn: lambda do |command, process_id|
        request = JSON.parse(Pathname.new(command.last).read)
        Pathname.new(request.fetch("startedPath")).write(JSON.dump("process_id" => process_id))
      end
    )
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.stopped(
        "avf-linux-efi-123",
        machine_requirements: machine_requirements,
        boot_config: linux_efi_boot_config,
        ssh_port: 2222,
        guest_ssh_info: { host: "192.168.64.6", port: 22, username: "vagrant" }
      )
    )
    driver = build_driver(
      process_control: process_control,
      helper_installer: -> { data_dir.join("fake-helper") }
    )

    metadata = driver.start(
      "avf-linux-efi-123",
      machine_requirements: machine_requirements,
      boot_config: linux_efi_boot_config,
      shared_directories: []
    )

    expect(metadata.guest_ssh_info.to_h).to eq(
      host: "192.168.64.6",
      port: 22,
      username: "vagrant"
    )
  end

  it "fails when the real boot slice is asked to start a non-headless machine" do
    process_control = FakeProcessControl.new
    driver = build_driver(
      process_control: process_control,
      helper_installer: -> { data_dir.join("fake-helper") }
    )
    non_headless_requirements = VagrantPlugins::AVF::Model::MachineRequirements.new(
      cpus: 2,
      memory_mb: 2048,
      disk_gb: 1,
      headless: false
    )

    expect {
      driver.start(
        "avf-123",
        machine_requirements: non_headless_requirements,
        boot_config: boot_config,
        shared_directories: []
      )
    }.to raise_error(VagrantPlugins::AVF::Errors::UnsupportedRuntimeConfiguration, /headless=true/)
  end

  it "reads the stored machine state when the helper process is alive" do
    process_control = FakeProcessControl.new(alive_processes: { 4321 => true })
    driver = build_driver(process_control: process_control)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-123",
        process_id: 4321,
        machine_requirements: machine_requirements,
        boot_config: boot_config,
        ssh_port: 2222
      )
    )

    expect(driver.read_state("avf-123")).to eq(:running)
  end

  it "downgrades stale running metadata to stopped when the helper process is gone" do
    process_control = FakeProcessControl.new(alive_processes: { 4321 => false })
    driver = build_driver(process_control: process_control)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-123",
        process_id: 4321,
        machine_requirements: machine_requirements,
        boot_config: boot_config,
        ssh_port: 2222,
        ssh_forwarder_process_id: 5678
      )
    )

    expect(driver.read_state("avf-123")).to eq(:stopped)
    expect(ssh_forwarder).to have_received(:stop).with(5678)
    expect(machine_metadata_store.fetch(machine_id: "avf-123").process_id).to be_nil
  end

  it "returns ssh info only for a running machine with a live helper process" do
    process_control = FakeProcessControl.new(alive_processes: { 4321 => true })
    ssh_forwarder = instance_double(
      VagrantPlugins::AVF::SshForwarder,
      alive?: true,
      start: 5678,
      stop: nil,
      cleanup_files: nil
    )
    driver = build_driver(process_control: process_control, ssh_forwarder: ssh_forwarder)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-123",
        process_id: 4321,
        ssh_info: { host: "127.0.0.1", port: 2222, username: "vagrant" },
        machine_requirements: machine_requirements,
        boot_config: boot_config,
        ssh_port: 2222,
        ssh_forwarder_process_id: 5678
      )
    )

    expect(driver.read_ssh_info("avf-123").to_h).to eq(
      host: "127.0.0.1",
      port: 2222,
      username: "vagrant"
    )
  end

  it "discovers ssh info from the console log and persists it" do
    process_control = FakeProcessControl.new(alive_processes: { 4321 => true })
    driver = build_driver(process_control: process_control)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-123",
        process_id: 4321,
        machine_requirements: machine_requirements,
        boot_config: boot_config,
        ssh_port: 2222
      )
    )
    data_dir.join("console.log").write(<<~LOG)
      booting
      __AVF_SSH_INFO__ {"host":"192.168.64.2","port":22,"username":"vagrant"}
    LOG

    ssh_info = driver.read_ssh_info("avf-123")

    expect(ssh_info.to_h).to eq(
      host: "127.0.0.1",
      port: 2222,
      username: "vagrant"
    )
    expect(machine_metadata_store.fetch(machine_id: "avf-123").ssh_info.to_h).to eq(
      host: "127.0.0.1",
      port: 2222,
      username: "vagrant"
    )
    expect(machine_metadata_store.fetch(machine_id: "avf-123").guest_ssh_info.to_h).to eq(
      host: "192.168.64.2",
      port: 22,
      username: "vagrant"
    )
    expect(machine_metadata_store.fetch(machine_id: "avf-123").ssh_forwarder_process_id).to eq(5678)
    expect(ssh_forwarder).to have_received(:start).with(
      listen_port: 2222,
      target_host: "192.168.64.2",
      target_port: 22
    )
  end

  it "reuses the last known guest ssh address after restart when it is still reachable" do
    process_control = FakeProcessControl.new(alive_processes: { 4321 => true })
    driver = build_driver(process_control: process_control)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-alma-123",
        process_id: 4321,
        machine_requirements: machine_requirements,
        boot_config: linux_efi_boot_config,
        ssh_port: 2222,
        guest_ssh_info: { host: "192.168.64.6", port: 22, username: "vagrant" }
      )
    )
    allow(Socket).to receive(:tcp).with("192.168.64.6", 22, connect_timeout: 0.5).and_yield(instance_double(BasicSocket, close: nil))

    ssh_info = driver.read_ssh_info("avf-alma-123")

    expect(ssh_info.to_h).to eq(
      host: "127.0.0.1",
      port: 2222,
      username: "vagrant"
    )
    expect(ssh_forwarder).to have_received(:start).with(
      listen_port: 2222,
      target_host: "192.168.64.6",
      target_port: 22
    )
    expect(machine_metadata_store.fetch(machine_id: "avf-alma-123").guest_ssh_info.to_h).to eq(
      host: "192.168.64.6",
      port: 22,
      username: "vagrant"
    )
  end

  it "ignores invalid ssh markers in the console log" do
    process_control = FakeProcessControl.new(alive_processes: { 4321 => true })
    driver = build_driver(process_control: process_control)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-123",
        process_id: 4321,
        machine_requirements: machine_requirements,
        boot_config: boot_config,
        ssh_port: 2222
      )
    )
    data_dir.join("console.log").write("__AVF_SSH_INFO__ not-json\n")

    expect(driver.read_ssh_info("avf-123")).to be_nil
    expect(machine_metadata_store.fetch(machine_id: "avf-123").ssh_info).to be_nil
  end

  it "discovers ssh info from DHCP leases when no guest marker is available" do
    process_control = FakeProcessControl.new(alive_processes: { 4321 => true })
    dhcp_leases = instance_double(VagrantPlugins::AVF::DhcpLeases, ip_address_for: "192.168.64.9")
    driver = build_driver(process_control: process_control, dhcp_leases: dhcp_leases)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-linux-123",
        process_id: 4321,
        machine_requirements: machine_requirements,
        boot_config: linux_efi_boot_config,
        ssh_port: 2222
      )
    )
    allow(Socket).to receive(:tcp).with("192.168.64.9", 22, connect_timeout: 0.5).and_yield(instance_double(BasicSocket, close: nil))

    ssh_info = driver.read_ssh_info("avf-linux-123")

    expect(ssh_info.to_h).to eq(
      host: "127.0.0.1",
      port: 2222,
      username: "vagrant"
    )
    expect(dhcp_leases).to have_received(:ip_address_for).with(
      mac_address: "02:#{Digest::SHA256.hexdigest("avf-linux-123")[0, 10].scan(/../).join(':')}"
    )
    expect(ssh_forwarder).to have_received(:start).with(
      listen_port: 2222,
      target_host: "192.168.64.9",
      target_port: 22
    )
  end

  it "does not trust a DHCP lease until ssh answers on port 22" do
    process_control = FakeProcessControl.new(alive_processes: { 4321 => true })
    dhcp_leases = instance_double(VagrantPlugins::AVF::DhcpLeases, ip_address_for: "192.168.64.9")
    driver = build_driver(process_control: process_control, dhcp_leases: dhcp_leases)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-linux-123",
        process_id: 4321,
        machine_requirements: machine_requirements,
        boot_config: linux_efi_boot_config,
        ssh_port: 2222
      )
    )
    allow(Socket).to receive(:tcp).with("192.168.64.9", 22, connect_timeout: 0.5).and_raise(Errno::ECONNREFUSED)

    expect(driver.read_ssh_info("avf-linux-123")).to be_nil
    expect(ssh_forwarder).not_to have_received(:start)
  end

  it "fails clearly when the stored ssh port is unavailable" do
    process_control = FakeProcessControl.new(alive_processes: { 4321 => true })
    port_allocator = instance_double(VagrantPlugins::AVF::PortAllocator)
    allow(port_allocator).to receive(:allocate).with(preferred_port: 2222)
      .and_raise(VagrantPlugins::AVF::Errors::SshPortUnavailable, "SSH forwarding port 2222 is unavailable")
    driver = build_driver(process_control: process_control, port_allocator: port_allocator)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-123",
        process_id: 4321,
        machine_requirements: machine_requirements,
        boot_config: boot_config,
        ssh_port: 2222
      )
    )
    data_dir.join("console.log").write('__AVF_SSH_INFO__ {"host":"192.168.64.2","port":22,"username":"vagrant"}')

    expect { driver.read_ssh_info("avf-123") }
      .to raise_error(VagrantPlugins::AVF::Errors::SshPortUnavailable, /2222/)
  end

  it "returns stopped metadata when a machine stops" do
    process_control = FakeProcessControl.new(alive_processes: { 4321 => true })
    driver = build_driver(process_control: process_control)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-123",
        process_id: 4321,
        ssh_info: { host: "127.0.0.1", port: 2222, username: "vagrant" },
        machine_requirements: machine_requirements,
        boot_config: boot_config,
        ssh_port: 2222,
        ssh_forwarder_process_id: 5678
      )
    )

    metadata = driver.stop("avf-123")

    expect(process_control.stopped_processes).to contain_exactly(
      process_id: 4321,
      timeout: described_class::STOP_TIMEOUT_SECONDS
    )
    expect(metadata.state).to eq(:stopped)
    expect(metadata.process_id).to be_nil
    expect(metadata.ssh_port).to eq(2222)
    expect(metadata.machine_requirements.to_h).to eq(machine_requirements.to_h)
    expect(ssh_forwarder).to have_received(:stop).with(5678)
  end

  it "wraps stop failures and leaves running metadata intact" do
    process_control = FakeProcessControl.new(
      alive_processes: { 4321 => true },
      on_stop: ->(_process_id, _timeout) { raise "permission denied" }
    )
    driver = build_driver(process_control: process_control)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-123",
        process_id: 4321,
        ssh_info: { host: "127.0.0.1", port: 2222, username: "vagrant" },
        machine_requirements: machine_requirements,
        boot_config: boot_config,
        ssh_port: 2222
      )
    )

    expect { driver.stop("avf-123") }
      .to raise_error(VagrantPlugins::AVF::Errors::MachineStopFailed, /permission denied/)

    persisted_metadata = machine_metadata_store.fetch(machine_id: "avf-123")
    expect(persisted_metadata.state).to eq(:running)
    expect(persisted_metadata.process_id).to eq(4321)
    expect(persisted_metadata.ssh_info.to_h).to eq(
      host: "127.0.0.1",
      port: 2222,
      username: "vagrant"
    )
  end

  it "clears persisted metadata and runtime files when a machine is destroyed" do
    process_control = FakeProcessControl.new
    driver = build_driver(process_control: process_control)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.stopped(
        "avf-123",
        machine_requirements: machine_requirements,
        boot_config: linux_efi_boot_config,
        ssh_port: 2222
      )
    )
    data_dir.join("disk.img").write("disk")
    data_dir.join("linux-efi.vars").write("efi")

    driver.destroy("avf-123")

    expect(machine_metadata_store.fetch).to be_nil
    expect(data_dir.join("disk.img")).not_to exist
    expect(data_dir.join("linux-efi.vars")).not_to exist
    expect(ssh_forwarder).to have_received(:cleanup_files)
  end

  it "stops a running machine before destroying it" do
    process_control = FakeProcessControl.new(alive_processes: { 4321 => true })
    driver = build_driver(process_control: process_control)
    machine_metadata_store.save(
      VagrantPlugins::AVF::Model::MachineMetadata.running(
        "avf-123",
        process_id: 4321,
        ssh_info: { host: "127.0.0.1", port: 2222, username: "vagrant" },
        machine_requirements: machine_requirements,
        boot_config: boot_config,
        ssh_port: 2222,
        ssh_forwarder_process_id: 5678
      )
    )
    data_dir.join("disk.img").write("disk")
    data_dir.join("avf-start-request.json").write("{}")
    data_dir.join("avf-started.json").write("{}")
    data_dir.join("avf-error.txt").write("error")
    data_dir.join("console.log").write("console")
    data_dir.join("avf-helper.log").write("helper")
    data_dir.join("avf-runner").write("binary")

    driver.destroy("avf-123")

    expect(process_control.stopped_processes).to contain_exactly(
      process_id: 4321,
      timeout: described_class::STOP_TIMEOUT_SECONDS
    )
    expect(machine_metadata_store.fetch).to be_nil
    expect(data_dir.join("disk.img")).not_to exist
    expect(data_dir.join("avf-start-request.json")).not_to exist
    expect(data_dir.join("avf-started.json")).not_to exist
    expect(data_dir.join("avf-error.txt")).not_to exist
    expect(data_dir.join("console.log")).not_to exist
    expect(data_dir.join("avf-helper.log")).not_to exist
    expect(data_dir.join("avf-runner")).not_to exist
    expect(ssh_forwarder).to have_received(:stop).with(5678)
    expect(ssh_forwarder).to have_received(:cleanup_files)
  end

  it "wraps cleanup failures during destroy" do
    broken_store = instance_double(
      VagrantPlugins::AVF::MachineMetadataStore,
      fetch: nil,
      clear: nil
    )
    allow(broken_store).to receive(:clear).and_raise("permission denied")
    driver = build_driver(
      machine_metadata_store: broken_store,
      process_control: FakeProcessControl.new
    )

    expect { driver.destroy(nil) }
      .to raise_error(VagrantPlugins::AVF::Errors::MachineDestroyFailed, /permission denied/)
  end
end
