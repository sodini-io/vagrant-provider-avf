module VagrantPlugins
  module AVF
    class DriverStartRequest
      DEFAULT_BOOT_COMMAND_LINE = "console=hvc0 root=LABEL=avf-root rw rootwait rootfstype=ext4".freeze

      def initialize(machine_id:, machine_requirements:, boot_config:, disk_path:, mac_address:, shared_directories:, seed_image_path:, efi_variable_store_path:, paths:)
        @machine_id = machine_id
        @machine_requirements = machine_requirements
        @boot_config = boot_config
        @disk_path = disk_path
        @mac_address = mac_address
        @shared_directories = shared_directories
        @seed_image_path = seed_image_path
        @efi_variable_store_path = efi_variable_store_path
        @paths = paths
      end

      def to_h
        {
          "guest" => @boot_config.guest.to_s,
          "cpuCount" => @machine_requirements.cpus,
          "memorySizeBytes" => @machine_requirements.memory_mb * 1024 * 1024,
          "kernelPath" => @boot_config.kernel_path,
          "initrdPath" => @boot_config.initrd_path,
          "diskImagePath" => @disk_path.to_s,
          "networkMacAddress" => @mac_address,
          "sharedDirectoryTag" => shared_directory_tag,
          "sharedDirectories" => @shared_directories.map(&:to_h),
          "seedImagePath" => @seed_image_path&.to_s,
          "seedImageReadOnly" => seed_image_read_only,
          "efiVariableStorePath" => @efi_variable_store_path&.to_s,
          "consoleLogPath" => @paths.console_log_path.to_s,
          "startedPath" => @paths.started_path.to_s,
          "errorPath" => @paths.error_path.to_s,
          "commandLine" => command_line
        }
      end

      private

      def shared_directory_tag
        return if @shared_directories.empty?

        Model::SharedDirectory::DEVICE_TAG
      end

      def seed_image_read_only
        return if @seed_image_path.nil?

        true
      end

      def command_line
        return unless @boot_config.linux_kernel_boot?

        DEFAULT_BOOT_COMMAND_LINE
      end
    end
  end
end
