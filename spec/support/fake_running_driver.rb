module TestSupport
  class FakeRunningDriver
    def initialize(machine, ssh_info: nil)
      @machine_metadata_store = VagrantPlugins::AVF::MachineMetadataStore.new(machine)
      @ssh_info = ssh_info
    end

    def fetch(machine_id)
      @machine_metadata_store.fetch(machine_id: machine_id)
    end

    def read_state(machine_id)
      metadata = fetch(machine_id)
      metadata && metadata.state
    end

    def read_ssh_info(machine_id)
      metadata = fetch(machine_id)
      return unless metadata && metadata.running?

      metadata.ssh_info
    end

    def create(machine_requirements, boot_config, machine_id: nil)
      metadata = VagrantPlugins::AVF::Model::MachineMetadata.stopped(
        machine_id || "avf-test-123",
        machine_requirements: machine_requirements,
        boot_config: boot_config
      )
      @machine_metadata_store.save(metadata)
      metadata
    end

    def start(machine_id, machine_requirements:, boot_config:, shared_directories: [])
      metadata = VagrantPlugins::AVF::Model::MachineMetadata.running(
        machine_id,
        process_id: 4242,
        ssh_info: @ssh_info,
        machine_requirements: machine_requirements,
        boot_config: boot_config
      )
      @machine_metadata_store.save(metadata)
      metadata
    end

    def stop(machine_id)
      metadata = fetch(machine_id)
      return unless metadata

      stopped_metadata = VagrantPlugins::AVF::Model::MachineMetadata.stopped(
        machine_id,
        machine_requirements: metadata.machine_requirements,
        boot_config: metadata.boot_config
      )
      @machine_metadata_store.save(stopped_metadata)
      stopped_metadata
    end

    def destroy(_machine_id)
      @machine_metadata_store.clear
    end
  end
end
