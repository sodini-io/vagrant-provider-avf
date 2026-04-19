module VagrantPlugins
  module AVF
    module Action
      def self.action_halt(machine, driver_factory:)
        Vagrant::Action::Builder.new.tap do |builder|
          builder.use(
            Halt,
            machine_id_store: MachineIdStore.new(machine),
            driver: driver_factory.call(machine)
          )
        end
      end

      class Halt
        def initialize(app, _env, machine_id_store:, driver:)
          @app = app
          @machine_id_store = machine_id_store
          @driver = driver
        end

        def call(env)
          machine_id = @machine_id_store.fetch
          @driver.stop(machine_id) unless blank?(machine_id) || stopped?(machine_id)
          @app.call(env)
        end

        private

        def stopped?(machine_id)
          @driver.read_state(machine_id) == :stopped
        end

        def blank?(value)
          value.nil? || value == ""
        end
      end
    end
  end
end
