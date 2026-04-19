require "spec_helper"

RSpec.describe VagrantPlugins::AVF::Action::SshInfo do
  it "returns nil when the machine does not exist" do
    machine = Struct.new(:id).new(nil)
    env = { machine: machine }
    driver = instance_double(VagrantPlugins::AVF::Driver)

    expect(driver).not_to receive(:read_ssh_info)

    described_class.new(->(_inner_env) {}, env, driver: driver).call(env)

    expect(env[:machine_ssh_info]).to be_nil
  end

  it "returns nil when ssh info is unavailable" do
    machine = Struct.new(:id).new("avf-123")
    env = { machine: machine }
    driver = instance_double(VagrantPlugins::AVF::Driver, read_ssh_info: nil)

    described_class.new(->(_inner_env) {}, env, driver: driver).call(env)

    expect(env[:machine_ssh_info]).to be_nil
  end

  it "returns a vagrant-compatible ssh info hash when metadata exists" do
    machine = Struct.new(:id).new("avf-123")
    env = { machine: machine }
    ssh_info = VagrantPlugins::AVF::Model::SshInfo.new(
      host: "127.0.0.1",
      port: 2222,
      username: "vagrant"
    )
    driver = instance_double(VagrantPlugins::AVF::Driver, read_ssh_info: ssh_info)

    described_class.new(->(_inner_env) {}, env, driver: driver).call(env)

    expect(env[:machine_ssh_info]).to eq(
      host: "127.0.0.1",
      port: 2222,
      username: "vagrant"
    )
  end
end
