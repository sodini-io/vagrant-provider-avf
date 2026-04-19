require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

module VagrantPlugins
  module AVF
    class LinuxCloudInitSeed
      SEED_LABEL = "cidata".freeze
      SEED_SIZE_MB = 8
      DEFAULT_USERNAME = "vagrant".freeze

      def initialize(
        machine_data_dir:,
        public_key_path: Pathname.new(File.expand_path("data/avf_insecure_key.pub", __dir__)),
        runner: nil
      )
        @path = Pathname.new(machine_data_dir).join("linux-seed.img")
        @public_key_path = Pathname.new(public_key_path)
        @runner = runner || method(:run_command)
      end

      attr_reader :path

      def write(machine_id:, mac_address:)
        public_key = @public_key_path.read.strip
        @path.dirname.mkpath
        create_blank_image

        disk = nil
        Dir.mktmpdir("avf-linux-seed") do |directory|
          disk = attach_disk
          format_disk(disk)
          mount_path = Pathname.new(directory).join("mount")
          mount_path.mkpath

          begin
            mount_disk(disk, mount_path)
            write_seed_files(mount_path, machine_id, mac_address, public_key)
          ensure
            unmount_disk(mount_path)
          end
        end

        @path
      rescue Errors::LinuxCloudInitSeedFailed
        raise
      rescue StandardError => error
        raise Errors::LinuxCloudInitSeedFailed, error.message
      ensure
        detach_disk(disk) if disk
      end

      private

      def create_blank_image
        File.open(@path, "wb") do |file|
          file.truncate(SEED_SIZE_MB * 1024 * 1024)
        end
      end

      def attach_disk
        output = @runner.call(
          "hdiutil",
          "attach",
          "-imagekey",
          "diskimage-class=CRawDiskImage",
          "-nomount",
          @path.to_s
        )
        disk = attached_disks(output).first
        raise Errors::LinuxCloudInitSeedFailed, "failed to attach #{@path}" if blank?(disk)

        disk
      end

      def format_disk(disk)
        @runner.call("newfs_msdos", "-v", SEED_LABEL, raw_disk(disk))
      end

      def mount_disk(disk, mount_path)
        @runner.call("mount", "-t", "msdos", disk, mount_path.to_s)
      end

      def unmount_disk(mount_path)
        return unless mount_path.exist?

        @runner.call("umount", mount_path.to_s)
      rescue StandardError
        nil
      end

      def detach_disk(disk)
        @runner.call("hdiutil", "detach", disk)
      rescue StandardError => error
        raise unless already_detached?(error)
      end

      def already_detached?(error)
        error.message.include?("No such file or directory")
      end

      def raw_disk(disk)
        disk.sub("/dev/disk", "/dev/rdisk")
      end

      def write_seed_files(mount_path, machine_id, mac_address, public_key)
        mount_path.join("meta-data").write(meta_data(machine_id))
        mount_path.join("network-config").write(network_config(mac_address))
        mount_path.join("user-data").write(user_data(public_key))
        cleanup_mount_artifacts(mount_path)
      end

      def meta_data(machine_id)
        [
          "instance-id: #{machine_id}",
          "local-hostname: avf-linux"
        ].join("\n") << "\n"
      end

      def network_config(mac_address)
        [
          "version: 2",
          "ethernets:",
          "  id0:",
          "    match:",
          "      macaddress: #{mac_address.downcase}",
          "    dhcp4: true"
        ].join("\n") << "\n"
      end

      def user_data(public_key)
        [
          "#cloud-config",
          "disable_root: true",
          "ssh_pwauth: false",
          "users:",
          "  - default",
          "  - name: #{DEFAULT_USERNAME}",
          "    gecos: Vagrant User",
          "    lock_passwd: true",
          "    shell: /bin/bash",
          "    sudo: ALL=(ALL) NOPASSWD:ALL",
          "    ssh_authorized_keys:",
          "      - #{public_key}",
          "growpart:",
          "  mode: auto",
          "  devices: [\"/\"]",
          "resize_rootfs: true",
          "write_files:",
          "  - path: /usr/local/libexec/avf-report-ssh-info",
          "    permissions: \"0755\"",
          "    owner: root:root",
          "    content: |",
          indent(report_ssh_info_script, 6).chomp,
          "runcmd:",
          "  - /usr/local/libexec/avf-report-ssh-info || true"
        ].join("\n") << "\n"
      end

      def report_ssh_info_script
        <<~SCRIPT
          #!/bin/sh
          set -eu

          attempt=0
          while [ "${attempt}" -lt 60 ]; do
            host="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ { for (i = 1; i <= NF; i += 1) if ($i == "src") { print $(i + 1); exit } }')"

            if [ -n "${host}" ]; then
              printf '__AVF_SSH_INFO__ {"host":"%s","port":22,"username":"#{DEFAULT_USERNAME}"}\\n' "${host}" > /dev/hvc0
              exit 0
            fi

            attempt=$((attempt + 1))
            sleep 1
          done
        SCRIPT
      end

      def cleanup_mount_artifacts(mount_path)
        mount_path.join(".fseventsd").rmtree if mount_path.join(".fseventsd").exist?
        mount_path.glob("**/._*").each(&:delete)
      end

      def indent(text, spaces)
        prefix = " " * spaces
        text.lines.map { |line| "#{prefix}#{line}" }.join
      end

      def attached_disks(output)
        output.lines.map { |line| line.split.first }.reject { |device| blank?(device) }
      end

      def run_command(*command)
        stdout, stderr, status = Open3.capture3({ "COPYFILE_DISABLE" => "1" }, *command)
        return stdout if status.success?

        message = stderr.strip
        message = stdout.strip if message.empty?
        message = command.join(" ") if message.empty?
        raise Errors::LinuxCloudInitSeedFailed, message
      end

      def blank?(value)
        value.nil? || value.to_s.empty?
      end
    end
  end
end
