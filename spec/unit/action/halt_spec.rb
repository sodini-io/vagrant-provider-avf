require "spec_helper"

RSpec.describe VagrantPlugins::AVF::Action::Halt do
  let(:app) { ->(env) { env[:app_called] = true } }
  let(:env) { {} }
  let(:machine_id_store) { instance_double(VagrantPlugins::AVF::MachineIdStore, fetch: machine_id) }
  let(:driver) { instance_double(VagrantPlugins::AVF::Driver, stop: stopped_metadata, read_state: machine_state) }
  let(:machine_id) { "avf-123" }
  let(:machine_state) { :running }
  let(:machine_requirements) do
    VagrantPlugins::AVF::Model::MachineRequirements.new(
      cpus: 2,
      memory_mb: 2048,
      disk_gb: 32,
      headless: true
    )
  end
  let(:machine_metadata) do
    VagrantPlugins::AVF::Model::MachineMetadata.running(
      machine_id,
      process_id: 4321,
      machine_requirements: machine_requirements
    )
  end
  let(:running_metadata) { machine_metadata }
  let(:stopped_metadata) do
    VagrantPlugins::AVF::Model::MachineMetadata.stopped(
      machine_id,
      machine_requirements: machine_requirements
    )
  end

  subject(:action) do
    described_class.new(
      app,
      env,
      machine_id_store: machine_id_store,
      driver: driver
    )
  end

  it "stops a running machine" do
    expect(driver).to receive(:read_state).with(machine_id).and_return(:running)
    expect(driver).to receive(:stop).with(machine_id).and_return(stopped_metadata)

    action.call(env)

    expect(env[:app_called]).to be(true)
  end

  it "does nothing when the machine does not exist" do
    allow(machine_id_store).to receive(:fetch).and_return(nil)

    expect(driver).not_to receive(:read_state)
    expect(driver).not_to receive(:stop)

    action.call(env)

    expect(env[:app_called]).to be(true)
  end

  it "does not stop an already stopped machine" do
    allow(driver).to receive(:read_state).with(machine_id).and_return(:stopped)

    expect(driver).not_to receive(:stop)

    action.call(env)
  end
end
