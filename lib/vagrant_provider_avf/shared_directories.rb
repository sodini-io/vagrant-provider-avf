module VagrantPlugins
  module AVF
    class SharedDirectories
      SYNCED_FOLDER_TYPE = :avf_virtiofs

      def self.for(machine)
        machine.config.vm.synced_folders.each_with_object([]) do |(id, data), shared_directories|
          next if data[:disabled]
          next unless supported_type?(data[:type])

          shared_directories << Model::SharedDirectory.new(
            id: id,
            host_path: expand_host_path(machine.env.root_path, data[:hostpath]),
            guest_path: data[:guestpath]
          )
        end
      end

      def self.supported_type?(type)
        return true if type.nil? || type.to_s.empty?

        type.to_sym == SYNCED_FOLDER_TYPE
      end

      def self.expand_host_path(root_path, host_path)
        expanded_path = File.expand_path(host_path, root_path.to_s)
        return File.realpath(expanded_path) if File.directory?(expanded_path)

        expanded_path
      end
    end
  end
end
