module VagrantPlugins
  module AVF
    module Model
      class MachineMetadata
        VALID_STATES = [:running, :stopped].freeze

        attr_reader :machine_id, :state, :ssh_info, :guest_ssh_info, :machine_requirements, :boot_config, :process_id, :ssh_port, :ssh_forwarder_process_id

        def self.running(
          machine_id,
          process_id:,
          ssh_info: nil,
          guest_ssh_info: nil,
          machine_requirements: nil,
          boot_config: nil,
          ssh_port: nil,
          ssh_forwarder_process_id: nil
        )
          new(
            machine_id: machine_id,
            state: :running,
            process_id: process_id,
            ssh_info: ssh_info,
            guest_ssh_info: guest_ssh_info,
            machine_requirements: machine_requirements,
            boot_config: boot_config,
            ssh_port: ssh_port,
            ssh_forwarder_process_id: ssh_forwarder_process_id
          )
        end

        def self.stopped(machine_id, ssh_info: nil, guest_ssh_info: nil, machine_requirements: nil, boot_config: nil, ssh_port: nil)
          new(
            machine_id: machine_id,
            state: :stopped,
            ssh_info: ssh_info,
            guest_ssh_info: guest_ssh_info,
            machine_requirements: machine_requirements,
            boot_config: boot_config,
            ssh_port: ssh_port
          )
        end

        def self.from_h(attributes)
          new(
            machine_id: attributes.fetch("machine_id"),
            state: attributes.fetch("state"),
            process_id: attributes["process_id"],
            ssh_info: attributes["ssh_info"],
            guest_ssh_info: attributes["guest_ssh_info"],
            machine_requirements: attributes["machine_requirements"],
            boot_config: attributes["boot_config"] || attributes["linux_boot_config"],
            ssh_port: attributes["ssh_port"],
            ssh_forwarder_process_id: attributes["ssh_forwarder_process_id"]
          )
        end

        def initialize(
          machine_id:,
          state:,
          process_id: nil,
          ssh_info: nil,
          guest_ssh_info: nil,
          machine_requirements: nil,
          boot_config: nil,
          ssh_port: nil,
          ssh_forwarder_process_id: nil
        )
          @machine_id = normalize_machine_id(machine_id)
          @state = normalize_state(state)
          @process_id = normalize_process_id(process_id, @state)
          @ssh_info = normalize_ssh_info(ssh_info)
          @guest_ssh_info = normalize_ssh_info(guest_ssh_info)
          @machine_requirements = normalize_machine_requirements(machine_requirements)
          @boot_config = normalize_boot_config(boot_config)
          @ssh_port = normalize_ssh_port(ssh_port)
          @ssh_forwarder_process_id = normalize_ssh_forwarder_process_id(ssh_forwarder_process_id, @state)
        end

        def running?
          @state == :running
        end

        def to_h
          {
            "machine_id" => @machine_id,
            "state" => @state.to_s,
            "process_id" => @process_id,
            "ssh_info" => @ssh_info && stringify_keys(@ssh_info.to_h),
            "guest_ssh_info" => @guest_ssh_info && stringify_keys(@guest_ssh_info.to_h),
            "machine_requirements" => @machine_requirements && @machine_requirements.to_h,
            "boot_config" => @boot_config && @boot_config.to_h,
            "ssh_port" => @ssh_port,
            "ssh_forwarder_process_id" => @ssh_forwarder_process_id
          }
        end

        private

        def normalize_machine_id(machine_id)
          value = machine_id.to_s
          raise ArgumentError, "machine_id is required" if value.empty?

          value
        end

        def normalize_state(state)
          value = state.to_sym
          return value if VALID_STATES.include?(value)

          raise ArgumentError, "state must be one of: #{VALID_STATES.join(', ')}"
        end

        def normalize_process_id(process_id, state)
          return if process_id.nil? && state == :stopped
          return process_id if process_id.is_a?(Integer) && process_id.positive?
          return process_id.to_i if process_id.is_a?(String) && process_id.match?(/\A\d+\z/) && process_id.to_i.positive?

          raise ArgumentError, "process_id must be a positive integer" if state == :running

          nil
        end

        def normalize_ssh_info(ssh_info)
          return if ssh_info.nil?
          return ssh_info if ssh_info.is_a?(SshInfo)

          SshInfo.from_h(ssh_info)
        end

        def normalize_machine_requirements(machine_requirements)
          return if machine_requirements.nil?
          return machine_requirements if machine_requirements.is_a?(MachineRequirements)

          MachineRequirements.from_h(machine_requirements)
        end

        def normalize_ssh_port(ssh_port)
          return if ssh_port.nil?
          return ssh_port if ssh_port.is_a?(Integer) && ssh_port.positive?
          return ssh_port.to_i if ssh_port.is_a?(String) && ssh_port.match?(/\A\d+\z/) && ssh_port.to_i.positive?

          raise ArgumentError, "ssh_port must be a positive integer"
        end

        def normalize_ssh_forwarder_process_id(process_id, state)
          return if process_id.nil?
          return process_id if process_id.is_a?(Integer) && process_id.positive?
          return process_id.to_i if process_id.is_a?(String) && process_id.match?(/\A\d+\z/) && process_id.to_i.positive?

          raise ArgumentError, "ssh_forwarder_process_id must be a positive integer" if state == :running

          nil
        end

        def normalize_boot_config(boot_config)
          return if boot_config.nil?
          return boot_config if boot_config.is_a?(BootConfig)

          BootConfig.from_h(boot_config)
        end

        def stringify_keys(hash)
          hash.each_with_object({}) do |(key, value), result|
            result[key.to_s] = value
          end
        end
      end
    end
  end
end
