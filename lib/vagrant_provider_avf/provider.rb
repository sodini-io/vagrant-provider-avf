module VagrantPlugins
  module AVF
    class Provider < Vagrant.plugin("2", :provider)
      def self.usable?(raise_error = false, host_platform: HostPlatform.current)
        return true if host_platform.supported?
        return false unless raise_error

        raise Errors::UnsupportedHost.new(host_platform)
      end

      def initialize(
        machine,
        driver_factory: ->(current_machine) {
          Driver.new(
            machine_metadata_store: MachineMetadataStore.new(current_machine),
            machine_data_dir: current_machine.data_dir
          )
        }
      )
        @machine = machine
        @driver_factory = driver_factory
      end

      def action(name)
        case name.to_sym
        when :read_state
          Action.action_read_state(@machine, driver_factory: @driver_factory)
        when :ssh
          Action.action_ssh
        when :ssh_run
          Action.action_ssh_run
        when :ssh_info
          Action.action_ssh_info(@machine, driver_factory: @driver_factory)
        when :up
          Action.action_up(@machine, driver_factory: @driver_factory)
        when :halt
          Action.action_halt(@machine, driver_factory: @driver_factory)
        when :destroy
          Action.action_destroy(@machine, driver_factory: @driver_factory)
        end
      end

      def ssh_info
        env = @machine.action(:ssh_info)
        return unless env.is_a?(Hash)

        env[:machine_ssh_info]
      end

      def state
        env = @machine.action(:read_state)
        return env.fetch(:machine_state) if env.is_a?(Hash)

        raise Errors::MissingMachineState
      rescue KeyError
        raise Errors::MissingMachineState
      end
    end
  end
end
