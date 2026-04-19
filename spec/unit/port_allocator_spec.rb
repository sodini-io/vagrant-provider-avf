require "spec_helper"

RSpec.describe VagrantPlugins::AVF::PortAllocator do
  class FakeServer
    def initialize(host, port)
      raise Errno::EADDRINUSE if host == "127.0.0.1" && self.class.unavailable_ports.include?(port)
    end

    def close
      true
    end

    def self.unavailable_ports
      @unavailable_ports ||= []
    end
  end

  before do
    FakeServer.unavailable_ports.clear
  end

  it "returns the preferred port when it is available" do
    allocator = described_class.new(server_class: FakeServer)

    expect(allocator.allocate(preferred_port: 2222)).to eq(2222)
  end

  it "raises when the preferred port is unavailable" do
    FakeServer.unavailable_ports << 2222
    allocator = described_class.new(server_class: FakeServer)

    expect { allocator.allocate(preferred_port: 2222) }
      .to raise_error(VagrantPlugins::AVF::Errors::SshPortUnavailable, /2222/)
  end

  it "scans the configured range and returns the first available port" do
    FakeServer.unavailable_ports.concat([2222, 2223])
    allocator = described_class.new(port_range: (2222..2225), server_class: FakeServer)

    expect(allocator.allocate).to eq(2224)
  end

  it "raises when no ports are available in the configured range" do
    FakeServer.unavailable_ports.concat([2222, 2223])
    allocator = described_class.new(port_range: (2222..2223), server_class: FakeServer)

    expect { allocator.allocate }
      .to raise_error(VagrantPlugins::AVF::Errors::SshPortUnavailable, /2222-2223/)
  end
end
