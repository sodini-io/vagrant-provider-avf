require "spec_helper"

RSpec.describe VagrantPlugins::AVF::Model::SshInfo do
  it "normalizes string keys and integer-like ports" do
    ssh_info = described_class.from_h(
      "host" => "127.0.0.1",
      "port" => "2222",
      "username" => "vagrant"
    )

    expect(ssh_info.host).to eq("127.0.0.1")
    expect(ssh_info.port).to eq(2222)
    expect(ssh_info.username).to eq("vagrant")
    expect(ssh_info.to_h).to eq(host: "127.0.0.1", port: 2222, username: "vagrant")
  end

  it "rejects missing required fields" do
    expect {
      described_class.from_h("host" => "127.0.0.1", "port" => 2222)
    }.to raise_error(ArgumentError, /username/)
  end

  it "rejects invalid ports" do
    expect {
      described_class.from_h("host" => "127.0.0.1", "port" => "many", "username" => "vagrant")
    }.to raise_error(ArgumentError, /port/)
  end
end
