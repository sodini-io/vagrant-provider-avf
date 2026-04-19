require "json"

module VagrantPlugins
  module AVF
    class MachineMetadataStore
      def initialize(machine)
        @path = machine.data_dir.join("machine_metadata.json")
      end

      def fetch(machine_id: nil)
        return if !@path.exist? || @path.size.zero?

        metadata = Model::MachineMetadata.from_h(JSON.parse(@path.read))
        return metadata if machine_id.nil?

        validate_machine_id!(metadata, machine_id)
      rescue JSON::ParserError, KeyError, ArgumentError => error
        raise Errors::InvalidMachineMetadata.new(@path, error)
      end

      def save(machine_metadata)
        @path.dirname.mkpath
        @path.write(JSON.dump(machine_metadata.to_h))
      end

      def clear
        @path.delete if @path.exist?
      end

      private

      def validate_machine_id!(metadata, machine_id)
        return metadata if metadata.machine_id == machine_id

        nil
      end
    end
  end
end
