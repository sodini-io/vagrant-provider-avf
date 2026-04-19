module VagrantPlugins
  module AVF
    module Action
      def self.action_destroy(machine, driver_factory:)
        Vagrant::Action::Builder.new.tap do |builder|
          builder.use(
            Destroy,
            machine_id_store: MachineIdStore.new(machine),
            driver: driver_factory.call(machine)
          )
        end
      end

      class Destroy
        def initialize(app, _env, machine_id_store:, driver:)
          @app = app
          @machine_id_store = machine_id_store
          @driver = driver
        end

        def call(env)
          destroy_machine
          @app.call(env)
        end

        private

        def destroy_machine
          machine_id = @machine_id_store.fetch
          @driver.destroy(machine_id)
          return if blank?(machine_id)

          @machine_id_store.clear
        end

        def blank?(value)
          value.nil? || value == ""
        end
      end
    end
  end
end
