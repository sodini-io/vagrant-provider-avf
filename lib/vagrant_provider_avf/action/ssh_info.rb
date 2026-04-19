module VagrantPlugins
  module AVF
    module Action
      def self.action_ssh_info(machine, driver_factory:)
        Vagrant::Action::Builder.new.tap do |builder|
          builder.use(
            SshInfo,
            machine_id_store: MachineIdStore.new(machine),
            driver: driver_factory.call(machine)
          )
        end
      end

      class SshInfo
        def initialize(
          app,
          env,
          machine_id_store: MachineIdStore.new(env[:machine]),
          driver: Driver.new(
            machine_metadata_store: MachineMetadataStore.new(env[:machine]),
            machine_data_dir: env[:machine].data_dir
          )
        )
          @app = app
          @machine_id_store = machine_id_store
          @driver = driver
        end

        def call(env)
          env[:machine_ssh_info] = machine_ssh_info
          @app.call(env)
        end

        private

        def machine_ssh_info
          return if blank?(machine_id)

          ssh_info = @driver.read_ssh_info(machine_id)
          ssh_info && ssh_info.to_h
        end

        def machine_id
          @machine_id_store.fetch
        end

        def blank?(value)
          value.nil? || value == ""
        end
      end
    end
  end
end
