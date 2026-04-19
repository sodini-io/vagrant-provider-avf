require "pathname"

module VagrantPlugins
  module AVF
    class DriverPaths
      def initialize(machine_data_dir)
        @machine_data_dir = Pathname.new(machine_data_dir)
      end

      def helper_source_path
        Pathname.new(File.expand_path("driver/avf_runner.swift", __dir__))
      end

      def helper_entitlements_path
        Pathname.new(File.expand_path("driver/virtualization.entitlements", __dir__))
      end

      def helper_binary_path
        @machine_data_dir.join("avf-runner")
      end

      def runtime_disk_path
        @machine_data_dir.join("disk.img")
      end

      def start_request_path
        @machine_data_dir.join("avf-start-request.json")
      end

      def started_path
        @machine_data_dir.join("avf-started.json")
      end

      def error_path
        @machine_data_dir.join("avf-error.txt")
      end

      def console_log_path
        @machine_data_dir.join("console.log")
      end

      def helper_log_path
        @machine_data_dir.join("avf-helper.log")
      end

      def efi_variable_store_path_for(boot_config)
        return linux_efi_variable_store_path if boot_config.linux_disk_boot?

        nil
      end

      def cleanup_paths(linux_cloud_init_seed_path:)
        [
          runtime_disk_path,
          linux_efi_variable_store_path,
          linux_cloud_init_seed_path,
          start_request_path,
          started_path,
          error_path,
          console_log_path,
          helper_log_path,
          helper_binary_path
        ]
      end

      private

      def linux_efi_variable_store_path
        @machine_data_dir.join("linux-efi.vars")
      end
    end
  end
end
