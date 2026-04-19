require "spec_helper"

RSpec.describe VagrantPlugins::AVF::MachineIdStore do
  it "reads, writes, and clears the machine id" do
    machine = Struct.new(:id).new
    store = described_class.new(machine)

    expect(store.fetch).to be_nil

    store.save("vm-123")
    expect(store.fetch).to eq("vm-123")

    store.clear
    expect(store.fetch).to be_nil
  end
end
