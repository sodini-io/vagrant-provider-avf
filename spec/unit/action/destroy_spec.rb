require "spec_helper"

RSpec.describe VagrantPlugins::AVF::Action::Destroy do
  let(:app) { ->(env) { env[:app_called] = true } }
  let(:env) { {} }
  let(:machine_id_store) { instance_double(VagrantPlugins::AVF::MachineIdStore, fetch: machine_id, clear: nil) }
  let(:driver) { instance_double(VagrantPlugins::AVF::Driver, destroy: nil) }
  let(:machine_id) { "avf-123" }

  subject(:action) do
    described_class.new(
      app,
      env,
      machine_id_store: machine_id_store,
      driver: driver
    )
  end

  it "destroys an existing machine and clears persisted state" do
    expect(driver).to receive(:destroy).with(machine_id)
    expect(machine_id_store).to receive(:clear)

    action.call(env)

    expect(env[:app_called]).to be(true)
  end

  it "clears metadata even when no machine id exists" do
    allow(machine_id_store).to receive(:fetch).and_return(nil)

    expect(driver).to receive(:destroy).with(nil)
    expect(machine_id_store).not_to receive(:clear)

    action.call(env)
  end

  it "does not clear the machine id when destroy fails" do
    allow(driver).to receive(:destroy).with(machine_id).and_raise(
      VagrantPlugins::AVF::Errors::MachineStopFailed,
      "permission denied"
    )

    expect(machine_id_store).not_to receive(:clear)

    expect { action.call(env) }
      .to raise_error(VagrantPlugins::AVF::Errors::MachineStopFailed, /permission denied/)
  end
end
