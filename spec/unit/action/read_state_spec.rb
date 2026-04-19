require "spec_helper"

RSpec.describe VagrantPlugins::AVF::Action::ReadState do
  it "reports not_created when the machine has no id" do
    machine = Struct.new(:id).new(nil)
    env = { machine: machine }
    app = ->(inner_env) { inner_env[:app_called] = true }
    driver = instance_double(VagrantPlugins::AVF::Driver)

    expect(driver).not_to receive(:read_state)

    described_class.new(app, env, driver: driver).call(env)

    expect(env[:app_called]).to be(true)
    expect(env[:machine_state]).to be_a(Vagrant::MachineState)
    expect(env[:machine_state].id).to eq(:not_created)
    expect(env[:machine_state].short_description).to eq("not created")
  end

  it "reports stopped when a machine id is present without metadata" do
    machine = Struct.new(:id).new("vm-123")
    env = { machine: machine }
    driver = instance_double(VagrantPlugins::AVF::Driver, read_state: nil)

    described_class.new(->(_inner_env) {}, env, driver: driver).call(env)

    expect(env[:machine_state].id).to eq(:stopped)
  end

  it "maps stored metadata to machine state" do
    machine = Struct.new(:id).new("vm-123")
    env = { machine: machine }
    driver = instance_double(VagrantPlugins::AVF::Driver, read_state: :running)

    described_class.new(->(_inner_env) {}, env, driver: driver).call(env)

    expect(env[:machine_state].id).to eq(:running)
  end

  it "treats mismatched metadata as stopped when a machine id exists" do
    machine = Struct.new(:id).new("vm-123")
    env = { machine: machine }
    driver = instance_double(VagrantPlugins::AVF::Driver, read_state: nil)

    described_class.new(->(_inner_env) {}, env, driver: driver).call(env)

    expect(env[:machine_state].id).to eq(:stopped)
  end
end
