module VagrantPlugins
  module AVF
    module Action
      def self.action_up(machine, driver_factory:)
        Vagrant::Action::Builder.new.tap do |builder|
          if machine.provider_config.boot_config.linux?
            builder.use(Vagrant::Action::Builtin::SyncedFolderCleanup)
            builder.use(Vagrant::Action::Builtin::SyncedFolders)
          end
          builder.use(
            Up,
            machine_id_store: MachineIdStore.new(machine),
            machine_requirements: machine.provider_config.machine_requirements,
            boot_config: machine.provider_config.boot_config,
            shared_directories: SharedDirectories.for(machine),
            driver: driver_factory.call(machine)
          )
          builder.use(Vagrant::Action::Builtin::WaitForCommunicator, [:running]) if machine.provider_config.boot_config.linux?
        end
      end

      class Up
        def initialize(app, _env, machine_id_store:, machine_requirements:, boot_config:, shared_directories:, driver:)
          @app = app
          @machine_id_store = machine_id_store
          @machine_requirements = machine_requirements
          @boot_config = boot_config
          @shared_directories = shared_directories
          @driver = driver
        end

        def call(env)
          validate_machine_configuration!
          start_machine
          @app.call(env)
        end

        private

        def validate_machine_configuration!
          errors = @machine_requirements.errors + @boot_config.errors
          return if errors.empty?

          raise Errors::InvalidMachineRequirements.new(errors)
        end

        def start_machine
          machine_id = @machine_id_store.fetch
          metadata = nil
          if blank?(machine_id)
            metadata = @driver.create(@machine_requirements, @boot_config)
            @machine_id_store.save(metadata.machine_id)
            machine_id = metadata.machine_id
          end

          metadata ||= @driver.fetch(machine_id)
          metadata = rebuild_metadata(machine_id) if metadata.nil? || metadata.machine_requirements.nil? || metadata.boot_config.nil?
          validate_persisted_machine_configuration!(metadata)
          return metadata if metadata.running?

          @driver.start(
            machine_id,
            machine_requirements: @machine_requirements,
            boot_config: @boot_config,
            shared_directories: @shared_directories
          )
        end

        def rebuild_metadata(machine_id)
          @driver.create(@machine_requirements, @boot_config, machine_id: machine_id)
        end

        def validate_persisted_machine_configuration!(metadata)
          return if metadata.nil?

          changed_fields = @machine_requirements.changed_fields(metadata.machine_requirements)
          changed_fields.concat(@boot_config.changed_fields(metadata.boot_config))
          changed_fields.uniq!
          return if changed_fields.empty?

          raise Errors::MachineRequirementsChanged.new(changed_fields)
        end

        def blank?(value)
          value.nil? || value == ""
        end
      end
    end
  end
end
