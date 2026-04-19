require "digest"
require "fileutils"
require "json"
require "pathname"
require "tmpdir"

module VagrantPlugins
  module AVF
    class BoxPackage
      PROVIDER = "avf".freeze
      ARCHITECTURE = "arm64".freeze
      USERNAME = "vagrant".freeze

      attr_reader :name, :version, :release, :guest, :kernel_path, :initrd_path, :disk_image_path, :private_key_path

      def initialize(name:, version:, release:, guest:, kernel_path:, initrd_path:, disk_image_path:, private_key_path:, description: nil, disk_gb: nil)
        @name = name.to_s
        @version = version.to_s
        @release = release.to_s
        @guest = guest.to_sym
        @kernel_path = kernel_path && File.expand_path(kernel_path)
        @initrd_path = initrd_path && File.expand_path(initrd_path)
        @disk_image_path = File.expand_path(disk_image_path)
        @private_key_path = File.expand_path(private_key_path)
        @description = description
        @disk_gb = disk_gb && Integer(disk_gb)
      end

      def validate!
        raise ArgumentError, "guest must be one of: linux" unless @guest == :linux

        missing_paths = artifact_entries.values.reject { |path| File.file?(path) }
        return self if missing_paths.empty?

        raise ArgumentError, "missing required box artifact: #{missing_paths.join(', ')}"
      end

      def archive_name
        "#{name.tr('/', '-')}-#{version}.box"
      end

      def metadata
        {
          "provider" => PROVIDER,
          "architecture" => ARCHITECTURE,
          "guest" => @guest.to_s,
          "format" => format,
          "release" => @release
        }
      end

      def info
        {
          "name" => @name,
          "version" => @version,
          "description" => description
        }
      end

      def artifact_entries
        entries = {
          "box/disk.img" => @disk_image_path,
          "box/insecure_private_key" => @private_key_path
        }
        return entries unless linux_kernel_artifacts?

        entries.merge(
          "box/vmlinuz" => @kernel_path,
          "box/initrd.img" => @initrd_path
        )
      end

      def metadata_json
        JSON.pretty_generate(metadata) << "\n"
      end

      def info_json
        JSON.pretty_generate(info) << "\n"
      end

      def write_archive(output_dir:, tar_command: "bsdtar")
        output_path = Pathname.new(output_dir).join(archive_name)
        output_path.dirname.mkpath

        Dir.mktmpdir("avf-box") do |staging|
          stage_archive(staging)
          build_archive(output_path, staging, tar_command)
        end

        output_path
      end

      def write_checksum(output_path)
        output_path = Pathname.new(output_path)
        checksum_path = output_path.dirname.join("#{output_path.basename}.sha256")
        checksum = Digest::SHA256.file(output_path).hexdigest
        checksum_path.write("#{checksum}  #{output_path.basename}\n")
        checksum_path
      end

      def vagrantfile
        (
          <<~RUBY
          Vagrant.configure("2") do |config|
            config.vm.communicator = "ssh"
          RUBY
        ) + default_synced_folder_vagrantfile + ssh_shell_vagrantfile + (
          <<~RUBY
            config.ssh.username = "#{USERNAME}"
            config.ssh.keys_only = true
            config.ssh.insert_key = false
            config.ssh.private_key_path = File.expand_path("box/insecure_private_key", __dir__)

            config.vm.provider :avf do |avf|
              avf.headless = true
              avf.guest = :#{@guest}
          RUBY
        ) + kernel_vagrantfile + (
          <<~RUBY
          #{disk_gb_vagrantfile}      avf.disk_image_path = File.expand_path("box/disk.img", __dir__)
            end
          end
          RUBY
        )
      end

      private

      def format
        return "linux-kernel-initrd-disk" if linux_kernel_artifacts?

        "efi-disk"
      end

      def description
        return @description unless @description.nil?

        "Minimal Ubuntu #{@release} ARM64 base box for vagrant-provider-avf"
      end

      def kernel_vagrantfile
        return "" unless linux_kernel_artifacts?

        <<~RUBY
              avf.kernel_path = File.expand_path("box/vmlinuz", __dir__)
              avf.initrd_path = File.expand_path("box/initrd.img", __dir__)
        RUBY
      end

      def disk_gb_vagrantfile
        return "" if @disk_gb.nil?

        "      avf.disk_gb = #{@disk_gb}\n"
      end

      def linux_kernel_artifacts?
        @guest == :linux && !@kernel_path.nil? && !@initrd_path.nil?
      end

      def default_synced_folder_vagrantfile
        ""
      end

      def ssh_shell_vagrantfile
        ""
      end

      def stage_archive(staging)
        staging_path = Pathname.new(staging)
        staging_path.join("box").mkpath
        stage_artifacts(staging_path)
        staging_path.join("metadata.json").write(metadata_json)
        staging_path.join("info.json").write(info_json)
        staging_path.join("Vagrantfile").write(vagrantfile)
      end

      def stage_artifacts(staging_path)
        artifact_entries.each do |entry, source|
          target = staging_path.join(entry)
          FileUtils.mkdir_p(target.dirname)
          FileUtils.cp(source, target)
          FileUtils.chmod(0o600, target) if entry.end_with?("insecure_private_key")
        end
      end

      def build_archive(output_path, staging, tar_command)
        system(tar_command, "-czf", output_path.to_s, "-C", staging, ".") or
          raise ArgumentError, "failed to build #{output_path}"
      end
    end
  end
end
