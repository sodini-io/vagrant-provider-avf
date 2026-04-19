require "spec_helper"
require "fileutils"
require "pathname"
require "tmpdir"

RSpec.describe VagrantPlugins::AVF::LinuxCloudInitSeed do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:public_key_path) { workspace.join("id_avf.pub") }

  before do
    public_key_path.write("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey vagrant\n")
  end

  after do
    FileUtils.remove_entry(workspace) if workspace.exist?
  end

  it "writes nocloud seed files into a raw fat disk image" do
    captured_commands = []
    captured_mount_path = nil
    captured_meta_data = nil
    captured_network_config = nil
    captured_user_data = nil

    runner = lambda do |*command|
      captured_commands << command

      if command[0, 5] == ["hdiutil", "attach", "-imagekey", "diskimage-class=CRawDiskImage", "-nomount"]
        "/dev/disk99\n"
      elsif command == ["newfs_msdos", "-v", "cidata", "/dev/rdisk99"]
        ""
      elsif command[0, 3] == ["mount", "-t", "msdos"]
        captured_mount_path = Pathname.new(command.last)
        captured_mount_path.join("._meta-data").write("sidecar")
        ""
      elsif command[0, 1] == ["umount"]
        expect(captured_mount_path.join("._meta-data")).not_to exist
        captured_meta_data = captured_mount_path.join("meta-data").read
        captured_network_config = captured_mount_path.join("network-config").read
        captured_user_data = captured_mount_path.join("user-data").read
        ""
      elsif command == ["hdiutil", "detach", "/dev/disk99"]
        ""
      else
        raise "unexpected command: #{command.inspect}"
      end
    end

    seed = described_class.new(
      machine_data_dir: workspace,
      public_key_path: public_key_path,
      runner: runner
    )

    result = seed.write(
      machine_id: "avf-linux-123",
      mac_address: "02:aa:bb:cc:dd:ee"
    )

    expect(result).to eq(workspace.join("linux-seed.img"))
    expect(result.exist?).to be(true)
    expect(result.size).to eq(8 * 1024 * 1024)
    expect(captured_commands).to eq(
      [
        ["hdiutil", "attach", "-imagekey", "diskimage-class=CRawDiskImage", "-nomount", result.to_s],
        ["newfs_msdos", "-v", "cidata", "/dev/rdisk99"],
        ["mount", "-t", "msdos", "/dev/disk99", captured_mount_path.to_s],
        ["umount", captured_mount_path.to_s],
        ["hdiutil", "detach", "/dev/disk99"]
      ]
    )
    expect(captured_meta_data).to eq("instance-id: avf-linux-123\nlocal-hostname: avf-linux\n")
    expect(captured_network_config).to include("macaddress: 02:aa:bb:cc:dd:ee")
    expect(captured_network_config).to include("dhcp4: true")
    expect(captured_user_data).to include("#cloud-config")
    expect(captured_user_data).to include("name: vagrant")
    expect(captured_user_data).to include("sudo: ALL=(ALL) NOPASSWD:ALL")
    expect(captured_user_data).to include("growpart:")
    expect(captured_user_data).to include("resize_rootfs: true")
    expect(captured_user_data).to include("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey vagrant")
    expect(captured_user_data).to include("/usr/local/libexec/avf-report-ssh-info")
    expect(captured_user_data).to include('__AVF_SSH_INFO__ {"host":"%s","port":22,"username":"vagrant"}')
  end

  it "raises a provider error when seed preparation fails" do
    seed = described_class.new(
      machine_data_dir: workspace,
      public_key_path: public_key_path,
      runner: ->(*_command) { raise "permission denied" }
    )

    expect {
      seed.write(machine_id: "avf-linux-123", mac_address: "02:aa:bb:cc:dd:ee")
    }.to raise_error(VagrantPlugins::AVF::Errors::LinuxCloudInitSeedFailed, /permission denied/)
  end

  it "ignores detach calls for devices that are already gone" do
    captured_commands = []

    runner = lambda do |*command|
      captured_commands << command

      if command[0, 5] == ["hdiutil", "attach", "-imagekey", "diskimage-class=CRawDiskImage", "-nomount"]
        "/dev/disk99\n"
      elsif command == ["newfs_msdos", "-v", "cidata", "/dev/rdisk99"]
        ""
      elsif command[0, 3] == ["mount", "-t", "msdos"]
        ""
      elsif command[0, 1] == ["umount"]
        ""
      elsif command == ["hdiutil", "detach", "/dev/disk99"]
        raise "hdiutil: detach failed - No such file or directory"
      else
        raise "unexpected command: #{command.inspect}"
      end
    end

    seed = described_class.new(
      machine_data_dir: workspace,
      public_key_path: public_key_path,
      runner: runner
    )

    expect {
      seed.write(machine_id: "avf-linux-123", mac_address: "02:aa:bb:cc:dd:ee")
    }.not_to raise_error

    expect(captured_commands.last).to eq(["hdiutil", "detach", "/dev/disk99"])
  end
end
