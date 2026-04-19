require "spec_helper"
require "fileutils"
require "pathname"
require "tmpdir"

RSpec.describe VagrantPlugins::AVF::SshForwarder do
  class ForwarderProcessControl
    def initialize(on_spawn:, alive: true)
      @on_spawn = on_spawn
      @alive = alive
    end

    def spawn(command, out:, err:)
      @on_spawn.call(command, out, err)
      5678
    end

    def alive?(_process_id)
      @alive
    end

    def stop(_process_id, timeout:)
      timeout
    end
  end

  let(:data_dir) { Pathname.new(Dir.mktmpdir) }

  after do
    FileUtils.remove_entry(data_dir) if data_dir.exist?
  end

  it "writes a request and waits for readiness" do
    control = ForwarderProcessControl.new(
      on_spawn: lambda do |command, _out, _err|
        request = JSON.parse(Pathname.new(command.last).read)
        expect(request).to include(
          "listen_host" => "127.0.0.1",
          "listen_port" => 2222,
          "target_host" => "192.168.64.2",
          "target_port" => 22
        )
        Pathname.new(request.fetch("ready_path")).write("ready")
      end
    )
    forwarder = described_class.new(machine_data_dir: data_dir, process_control: control, ruby_path: "/usr/bin/ruby")

    process_id = forwarder.start(listen_port: 2222, target_host: "192.168.64.2", target_port: 22)

    expect(process_id).to eq(5678)
  end

  it "raises a clear error when the runner reports a startup error" do
    control = ForwarderProcessControl.new(
      on_spawn: lambda do |command, _out, _err|
        request = JSON.parse(Pathname.new(command.last).read)
        Pathname.new(request.fetch("error_path")).write("bind failed")
      end
    )
    forwarder = described_class.new(machine_data_dir: data_dir, process_control: control, ruby_path: "/usr/bin/ruby")

    expect {
      forwarder.start(listen_port: 2222, target_host: "192.168.64.2", target_port: 22)
    }.to raise_error(VagrantPlugins::AVF::Errors::SshForwarderStartFailed, /bind failed/)
  end

  it "raises a clear error when the forwarder exits before reporting readiness" do
    control = ForwarderProcessControl.new(
      on_spawn: ->(_command, _out, _err) {},
      alive: false
    )
    forwarder = described_class.new(machine_data_dir: data_dir, process_control: control, ruby_path: "/usr/bin/ruby")

    expect {
      forwarder.start(listen_port: 2222, target_host: "192.168.64.2", target_port: 22)
    }.to raise_error(VagrantPlugins::AVF::Errors::SshForwarderStartFailed, /exited before reporting readiness/)
  end
end
