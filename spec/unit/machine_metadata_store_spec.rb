require "spec_helper"
require "fileutils"
require "pathname"
require "tmpdir"

RSpec.describe VagrantPlugins::AVF::MachineMetadataStore do
  let(:data_dir) { Pathname.new(Dir.mktmpdir) }
  let(:machine) { Struct.new(:data_dir).new(data_dir) }
  let(:store) { described_class.new(machine) }

  after do
    FileUtils.remove_entry(data_dir) if data_dir.exist?
  end

  it "returns nil when no metadata has been stored" do
    expect(store.fetch).to be_nil
  end

  it "round-trips machine metadata" do
    metadata = VagrantPlugins::AVF::Model::MachineMetadata.running(
      "avf-123",
      process_id: 1234,
      ssh_info: { host: "127.0.0.1", port: 2222, username: "vagrant" },
      ssh_port: 2222,
      ssh_forwarder_process_id: 5678
    )

    store.save(metadata)

    fetched = store.fetch
    expect(fetched.machine_id).to eq("avf-123")
    expect(fetched.state).to eq(:running)
    expect(fetched.process_id).to eq(1234)
    expect(fetched.ssh_port).to eq(2222)
    expect(fetched.ssh_forwarder_process_id).to eq(5678)
    expect(fetched.ssh_info.to_h).to eq(host: "127.0.0.1", port: 2222, username: "vagrant")
  end

  it "returns metadata when it matches the requested machine id" do
    store.save(VagrantPlugins::AVF::Model::MachineMetadata.running("avf-123", process_id: 1234))

    fetched = store.fetch(machine_id: "avf-123")

    expect(fetched.machine_id).to eq("avf-123")
  end

  it "clears persisted metadata" do
    store.save(VagrantPlugins::AVF::Model::MachineMetadata.stopped("avf-123"))

    store.clear

    expect(store.fetch).to be_nil
  end

  it "raises a clear error for malformed json" do
    data_dir.join("machine_metadata.json").write("{")

    expect { store.fetch }
      .to raise_error(VagrantPlugins::AVF::Errors::InvalidMachineMetadata, /machine_metadata\.json/)
  end

  it "raises a clear error for invalid metadata payloads" do
    data_dir.join("machine_metadata.json").write(
      JSON.dump(
        "machine_id" => "avf-123",
        "state" => "running",
        "process_id" => 1234,
        "ssh_info" => { "host" => "127.0.0.1", "port" => 2222 }
      )
    )

    expect { store.fetch }
      .to raise_error(VagrantPlugins::AVF::Errors::InvalidMachineMetadata, /username/)
  end

  it "returns nil when stored metadata belongs to a different machine id" do
    store.save(VagrantPlugins::AVF::Model::MachineMetadata.running("avf-123", process_id: 1234))

    expect(store.fetch(machine_id: "avf-999")).to be_nil
  end
end
