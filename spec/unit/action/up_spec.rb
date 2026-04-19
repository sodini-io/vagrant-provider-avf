require "spec_helper"

RSpec.describe VagrantPlugins::AVF::Action::Up do
  let(:app) { ->(env) { env[:app_called] = true } }
  let(:env) { {} }
  let(:machine_id_store) { instance_double(VagrantPlugins::AVF::MachineIdStore, fetch: existing_machine_id, save: nil) }
  let(:driver) do
    instance_double(
      VagrantPlugins::AVF::Driver,
      create: stopped_metadata,
      fetch: existing_machine_metadata,
      start: running_metadata
    )
  end
  let(:machine_requirements) do
    instance_double(
      VagrantPlugins::AVF::Model::MachineRequirements,
      errors: machine_requirement_errors,
      changed_fields: changed_fields
    )
  end
  let(:boot_config) do
    instance_double(
      VagrantPlugins::AVF::Model::BootConfig,
      errors: boot_config_errors,
      changed_fields: boot_changed_fields
    )
  end
  let(:existing_machine_id) { nil }
  let(:existing_machine_metadata) { nil }
  let(:machine_requirement_errors) { [] }
  let(:boot_config_errors) { [] }
  let(:changed_fields) { [] }
  let(:boot_changed_fields) { [] }
  let(:shared_directories) { [] }
  let(:persisted_machine_requirements) do
    VagrantPlugins::AVF::Model::MachineRequirements.new(
      cpus: 2,
      memory_mb: 2048,
      disk_gb: 32,
      headless: true
    )
  end
  let(:persisted_boot_config) do
    VagrantPlugins::AVF::Model::BootConfig.new(
      guest: :linux,
      kernel_path: "/tmp/kernel",
      initrd_path: "/tmp/initrd",
      disk_image_path: "/tmp/disk.img"
    )
  end
  let(:stopped_metadata) do
    VagrantPlugins::AVF::Model::MachineMetadata.stopped(
      "avf-123",
      machine_requirements: persisted_machine_requirements,
      boot_config: persisted_boot_config
    )
  end
  let(:running_metadata) do
    VagrantPlugins::AVF::Model::MachineMetadata.running(
      "avf-123",
      process_id: 4321,
      machine_requirements: persisted_machine_requirements,
      boot_config: persisted_boot_config
    )
  end

  subject(:action) do
    described_class.new(
      app,
      env,
      machine_id_store: machine_id_store,
      machine_requirements: machine_requirements,
      boot_config: boot_config,
      shared_directories: shared_directories,
      driver: driver
    )
  end

  it "creates and starts a machine when it does not exist" do
    expect(driver).to receive(:create).with(machine_requirements, boot_config).and_return(stopped_metadata)
    expect(machine_id_store).to receive(:save).with("avf-123")
    expect(driver).to receive(:start).with(
      "avf-123",
      machine_requirements: machine_requirements,
      boot_config: boot_config,
      shared_directories: shared_directories
    ).and_return(running_metadata)

    action.call(env)

    expect(env[:app_called]).to be(true)
  end

  it "starts an existing stopped machine without creating a second record" do
    allow(machine_id_store).to receive(:fetch).and_return("avf-123")
    allow(driver).to receive(:fetch).with("avf-123").and_return(stopped_metadata)

    expect(driver).not_to receive(:create)
    expect(machine_id_store).not_to receive(:save)
    expect(driver).to receive(:start).with(
      "avf-123",
      machine_requirements: machine_requirements,
      boot_config: boot_config,
      shared_directories: shared_directories
    ).and_return(running_metadata)

    action.call(env)

    expect(env[:app_called]).to be(true)
  end

  it "rebuilds missing metadata before starting an existing machine id" do
    allow(machine_id_store).to receive(:fetch).and_return("avf-123")

    expect(machine_id_store).not_to receive(:save)
    expect(driver).to receive(:create).with(machine_requirements, boot_config, machine_id: "avf-123").and_return(stopped_metadata)
    expect(driver).to receive(:start).with(
      "avf-123",
      machine_requirements: machine_requirements,
      boot_config: boot_config,
      shared_directories: shared_directories
    ).and_return(running_metadata)

    action.call(env)
  end

  it "preserves running metadata when a machine is already running" do
    allow(machine_id_store).to receive(:fetch).and_return("avf-123")
    allow(driver).to receive(:fetch).with("avf-123").and_return(running_metadata)

    expect(driver).not_to receive(:create)
    expect(machine_id_store).not_to receive(:save)
    expect(driver).not_to receive(:start)

    action.call(env)
  end

  it "fails when persisted machine requirements changed" do
    allow(machine_id_store).to receive(:fetch).and_return("avf-123")
    allow(driver).to receive(:fetch).with("avf-123").and_return(stopped_metadata)
    allow(machine_requirements).to receive(:changed_fields).with(persisted_machine_requirements).and_return([:cpus, :disk_gb])

    expect(driver).not_to receive(:create)
    expect(driver).not_to receive(:start)

    expect { action.call(env) }
      .to raise_error(VagrantPlugins::AVF::Errors::MachineRequirementsChanged, /cpus, disk_gb/)
  end

  it "fails when persisted boot settings changed" do
    allow(machine_id_store).to receive(:fetch).and_return("avf-123")
    allow(driver).to receive(:fetch).with("avf-123").and_return(stopped_metadata)
    allow(boot_config).to receive(:changed_fields).with(persisted_boot_config).and_return([:kernel_path])

    expect(driver).not_to receive(:create)
    expect(driver).not_to receive(:start)

    expect { action.call(env) }
      .to raise_error(VagrantPlugins::AVF::Errors::MachineRequirementsChanged, /kernel_path/)
  end

  it "does not read existing metadata before creating a new machine id" do
    allow(driver).to receive(:fetch).and_raise("should not read metadata before machine id exists")

    expect(driver).to receive(:create).with(machine_requirements, boot_config).and_return(stopped_metadata)
    expect(machine_id_store).to receive(:save).with("avf-123")
    expect(driver).to receive(:start).with(
      "avf-123",
      machine_requirements: machine_requirements,
      boot_config: boot_config,
      shared_directories: shared_directories
    ).and_return(running_metadata)

    action.call(env)
  end

  it "fails fast when machine configuration is invalid" do
    allow(machine_requirements).to receive(:errors).and_return(["cpus must be greater than 0"])
    allow(boot_config).to receive(:errors).and_return(["kernel_path is required"])

    expect(driver).not_to receive(:create)
    expect(driver).not_to receive(:start)
    expect(machine_id_store).not_to receive(:save)
    expect(driver).not_to receive(:fetch)

    expect { action.call(env) }
      .to raise_error(
        VagrantPlugins::AVF::Errors::InvalidMachineRequirements,
        /cpus must be greater than 0, kernel_path is required/
      )
  end
end
