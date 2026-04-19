module VagrantPlugins
  module AVF
    module Action
      def self.action_read_state(machine, driver_factory:)
        Vagrant::Action::Builder.new.tap do |builder|
          builder.use(
            ReadState,
            machine_id_store: MachineIdStore.new(machine),
            driver: driver_factory.call(machine)
          )
        end
      end

      class ReadState
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
          env[:machine_state] = machine_state
          @app.call(env)
        end

        private

        def machine_state
          return Model::MachineState.not_created if blank?(machine_id)

          state = @driver.read_state(machine_id)
          return Model::MachineState.stopped if state.nil?

          Model::MachineState.for(state)
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
