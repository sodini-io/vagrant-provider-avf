require "spec_helper"

RSpec.describe VagrantPlugins::AVF::HelperInstaller do
  let(:data_dir) { Pathname.new(Dir.mktmpdir) }
  let(:source_path) { data_dir.join("avf_runner.swift") }
  let(:entitlements_path) { data_dir.join("virtualization.entitlements") }
  let(:binary_path) { data_dir.join("avf-runner") }
  let(:paths) do
    instance_double(
      VagrantPlugins::AVF::DriverPaths,
      helper_source_path: source_path,
      helper_entitlements_path: entitlements_path,
      helper_binary_path: binary_path
    )
  end

  after do
    FileUtils.remove_entry(data_dir) if data_dir.exist?
  end

  before do
    source_path.write("source")
    entitlements_path.write("entitlements")
  end

  it "builds and signs the helper when the binary is missing" do
    commands = []
    installer = described_class.new(
      paths: paths,
      command_runner: lambda do |*command|
        commands << command
        binary_path.write("binary") if command.first == "xcrun"
        ["", "", instance_double(Process::Status, success?: true)]
      end
    )

    result = installer.install

    expect(result).to eq(binary_path)
    expect(commands).to eq(
      [
        ["xcrun", "swiftc", source_path.to_s, "-o", binary_path.to_s],
        ["codesign", "-f", "-s", "-", "--entitlements", entitlements_path.to_s, binary_path.to_s]
      ]
    )
  end

  it "reuses an up-to-date helper binary" do
    binary_path.write("binary")
    File.utime(Time.now + 60, Time.now + 60, binary_path)

    installer = described_class.new(
      paths: paths,
      command_runner: lambda do |_command|
        raise "should not rebuild an up-to-date helper"
      end
    )

    expect(installer.install).to eq(binary_path)
  end

  it "wraps helper build failures in a provider error" do
    installer = described_class.new(
      paths: paths,
      command_runner: lambda do |*command|
        ["", "swift failed", instance_double(Process::Status, success?: false)]
      end
    )

    expect { installer.install }
      .to raise_error(VagrantPlugins::AVF::Errors::AvfHelperBuildFailed, /swift failed/)
  end
end
