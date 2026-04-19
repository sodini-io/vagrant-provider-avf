module VagrantPlugins
  module AVF
    class MachineIdStore
      def initialize(machine)
        @machine = machine
      end

      def fetch
        @machine.id
      end

      def save(machine_id)
        @machine.id = machine_id
      end

      def clear
        @machine.id = nil
      end
    end
  end
end
