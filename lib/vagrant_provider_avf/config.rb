module VagrantPlugins
  module AVF
    class Config < Vagrant.plugin("2", :config)
      attr_accessor :cpus, :memory_mb, :disk_gb, :headless, :guest, :kernel_path, :initrd_path, :disk_image_path

      def initialize
        @cpus = UNSET_VALUE
        @memory_mb = UNSET_VALUE
        @disk_gb = UNSET_VALUE
        @headless = UNSET_VALUE
        @guest = UNSET_VALUE
        @kernel_path = UNSET_VALUE
        @initrd_path = UNSET_VALUE
        @disk_image_path = UNSET_VALUE
      end

      def finalize!
        @cpus = nil if @cpus == UNSET_VALUE
        @memory_mb = nil if @memory_mb == UNSET_VALUE
        @disk_gb = nil if @disk_gb == UNSET_VALUE
        @headless = true if @headless == UNSET_VALUE
        @guest = :linux if @guest == UNSET_VALUE
        @kernel_path = nil if @kernel_path == UNSET_VALUE
        @initrd_path = nil if @initrd_path == UNSET_VALUE
        @disk_image_path = nil if @disk_image_path == UNSET_VALUE
      end

      def validate(_machine)
        errors = _detected_errors + machine_requirements.errors + boot_config.errors

        return {} if errors.empty?

        { "AVF provider" => errors }
      end

      def machine_requirements
        Model::MachineRequirements.new(
          cpus: @cpus,
          memory_mb: @memory_mb,
          disk_gb: @disk_gb,
          headless: @headless
        )
      end

      def boot_config
        Model::BootConfig.new(
          guest: @guest,
          kernel_path: @kernel_path,
          initrd_path: @initrd_path,
          disk_image_path: @disk_image_path
        )
      end

      private
    end
  end
end
