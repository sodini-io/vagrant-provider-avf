require "spec_helper"
require "fileutils"
require "rubygems/package"
require "pathname"
require "tmpdir"
require "zlib"

RSpec.describe VagrantPlugins::AVF::BoxPackage do
  let(:data_dir) { Pathname.new(Dir.mktmpdir) }

  before do
    data_dir.join("vmlinuz").write("kernel")
    data_dir.join("initrd.img").write("initrd")
    data_dir.join("disk.img").write("disk")
    data_dir.join("insecure_private_key").write("private")
  end

  after do
    FileUtils.remove_entry(data_dir) if data_dir.exist?
  end

  subject(:package) do
    described_class.new(
      name: "avf/ubuntu-24.04-arm64",
      version: "0.1.0",
      release: "24.04.4",
      guest: :linux,
      kernel_path: data_dir.join("vmlinuz"),
      initrd_path: data_dir.join("initrd.img"),
      disk_image_path: data_dir.join("disk.img"),
      private_key_path: data_dir.join("insecure_private_key")
    )
  end

  it "describes the avf box metadata and required artifacts" do
    expect(package.validate!).to eq(package)
    expect(package.archive_name).to eq("avf-ubuntu-24.04-arm64-0.1.0.box")
    expect(package.metadata).to eq(
      "provider" => "avf",
      "architecture" => "arm64",
      "guest" => "linux",
      "format" => "linux-kernel-initrd-disk",
      "release" => "24.04.4"
    )
    expect(package.artifact_entries.keys).to contain_exactly(
      "box/vmlinuz",
      "box/initrd.img",
      "box/disk.img",
      "box/insecure_private_key"
    )
  end

  it "supports a disk-only linux box package" do
    linux_efi_package = described_class.new(
      name: "avf/ubuntu-24.04-arm64",
      version: "0.1.0",
      release: "24.04",
      guest: :linux,
      kernel_path: nil,
      initrd_path: nil,
      disk_image_path: data_dir.join("disk.img"),
      private_key_path: data_dir.join("insecure_private_key")
    )

    expect(linux_efi_package.validate!).to eq(linux_efi_package)
    expect(linux_efi_package.metadata).to eq(
      "provider" => "avf",
      "architecture" => "arm64",
      "guest" => "linux",
      "format" => "efi-disk",
      "release" => "24.04"
    )
    expect(linux_efi_package.artifact_entries.keys).to contain_exactly(
      "box/disk.img",
      "box/insecure_private_key"
    )
    expect(linux_efi_package.vagrantfile).to include("avf.guest = :linux")
    expect(linux_efi_package.vagrantfile).not_to include("avf.kernel_path")
  end

  it "generates an embedded Vagrantfile for the curated avf box flow" do
    expect(package.vagrantfile).to include('config.ssh.username = "vagrant"')
    expect(package.vagrantfile).to include('config.ssh.keys_only = true')
    expect(package.vagrantfile).to include('config.ssh.private_key_path = File.expand_path("box/insecure_private_key", __dir__)')
    expect(package.vagrantfile).to include('avf.kernel_path = File.expand_path("box/vmlinuz", __dir__)')
    expect(package.vagrantfile).to include('avf.disk_image_path = File.expand_path("box/disk.img", __dir__)')
    expect(package.vagrantfile).not_to include('config.vm.synced_folder ".", "/vagrant", disabled: true')
  end

  it "allows a caller-provided box description" do
    alma_package = described_class.new(
      name: "avf/almalinux-9-arm64",
      version: "0.1.0",
      release: "9.7-20260414",
      guest: :linux,
      kernel_path: nil,
      initrd_path: nil,
      disk_image_path: data_dir.join("disk.img"),
      private_key_path: data_dir.join("insecure_private_key"),
      description: "Minimal AlmaLinux 9.7 ARM64 base box for vagrant-provider-avf"
    )

    expect(alma_package.validate!).to eq(alma_package)
    expect(alma_package.info.fetch("description")).to eq(
      "Minimal AlmaLinux 9.7 ARM64 base box for vagrant-provider-avf"
    )
  end

  it "can embed a default disk size for the box guest" do
    alma_package = described_class.new(
      name: "avf/almalinux-9-arm64",
      version: "0.1.0",
      release: "9.7-20260414",
      guest: :linux,
      kernel_path: nil,
      initrd_path: nil,
      disk_image_path: data_dir.join("disk.img"),
      private_key_path: data_dir.join("insecure_private_key"),
      disk_gb: 12
    )

    expect(alma_package.validate!).to eq(alma_package)
    expect(alma_package.vagrantfile).to include("avf.disk_gb = 12")
  end

  it "writes a box archive and checksum" do
    output_dir = data_dir.join("out")

    archive_path = package.write_archive(output_dir: output_dir)
    checksum_path = package.write_checksum(archive_path)

    expect(archive_path).to exist
    expect(checksum_path.read).to match(/#{Regexp.escape(archive_path.basename.to_s)}\n\z/)

    entries = {}
    Zlib::GzipReader.open(archive_path.to_s) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each do |entry|
          entries[entry.full_name.sub(%r{\A\./}, "")] = entry.file? ? entry.read : nil
        end
      end
    end

    expect(entries.keys).to include(
      "metadata.json",
      "info.json",
      "Vagrantfile",
      "box/vmlinuz",
      "box/initrd.img",
      "box/disk.img",
      "box/insecure_private_key"
    )
    expect(entries.fetch("Vagrantfile")).to include('avf.guest = :linux')
  end

  it "rejects missing box artifacts" do
    data_dir.join("disk.img").delete

    expect { package.validate! }
      .to raise_error(ArgumentError, /missing required box artifact: .*disk\.img/)
  end

  it "rejects an unsupported guest" do
    invalid_package = described_class.new(
      name: "avf/example",
      version: "0.1.0",
      release: "0.1.0",
      guest: :dragonfly,
      kernel_path: nil,
      initrd_path: nil,
      disk_image_path: data_dir.join("disk.img"),
      private_key_path: data_dir.join("insecure_private_key")
    )

    expect { invalid_package.validate! }.to raise_error(ArgumentError, /guest must be one of/)
  end
end
