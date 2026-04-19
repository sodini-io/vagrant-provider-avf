require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe VagrantPlugins::AVF::DhcpLeases do
  let(:directory) { Dir.mktmpdir }
  let(:path) { File.join(directory, "dhcpd_leases") }

  after do
    FileUtils.remove_entry(directory) if File.exist?(directory)
  end

  it "finds an ip address for a mac address in a prefixed lease record" do
    File.write(
      path,
      <<~LEASES
        {
        name=avf-linux
        ip_address=192.168.64.9
        hw_address=1,02:00:aa:bb:cc:dd
        }
      LEASES
    )

    leases = described_class.new(path: path)

    expect(leases.ip_address_for(mac_address: "02:00:aa:bb:cc:dd")).to eq("192.168.64.9")
  end

  it "returns the newest matching lease" do
    File.write(
      path,
      <<~LEASES
        {
        ip_address=192.168.64.8
        identifier=02:00:aa:bb:cc:dd
        }
        {
        ip_address=192.168.64.9
        hw_address=1,02:00:aa:bb:cc:dd
        }
      LEASES
    )

    leases = described_class.new(path: path)

    expect(leases.ip_address_for(mac_address: "02:00:aa:bb:cc:dd")).to eq("192.168.64.9")
  end

  it "returns nil when no lease matches" do
    File.write(path, "{\nip_address=192.168.64.9\nhw_address=1,02:00:aa:bb:cc:dd\n}\n")

    leases = described_class.new(path: path)

    expect(leases.ip_address_for(mac_address: "02:00:00:00:00:01")).to be_nil
  end
end
