module VagrantPlugins
  module AVF
    module Model
      class MachineState < Vagrant::MachineState
        def self.not_created
          new(
            :not_created,
            short_description: "not created",
            long_description: "The machine has not been created."
          )
        end

        def self.unknown
          new(
            :unknown,
            short_description: "unknown",
            long_description: "The machine exists, but its AVF state has not been implemented yet."
          )
        end

        def self.running
          new(
            :running,
            short_description: "running",
            long_description: "The machine is running."
          )
        end

        def self.stopped
          new(
            :stopped,
            short_description: "stopped",
            long_description: "The machine has been created, but it is not running."
          )
        end

        def self.for(state)
          return not_created if state.to_sym == :not_created
          return running if state.to_sym == :running
          return stopped if state.to_sym == :stopped

          unknown
        end

        def initialize(id, short_description:, long_description:)
          super(id, short_description, long_description)
        end
      end
    end
  end
end
