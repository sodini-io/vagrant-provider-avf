module VagrantPlugins
  module AVF
    module Errors
      class InvalidMachineRequirements < StandardError
        def initialize(errors)
          super("invalid machine requirements: #{errors.join(', ')}")
        end
      end

      class UnsupportedRuntimeConfiguration < StandardError
        def initialize(message)
          super(message)
        end
      end

      class InvalidMachineMetadata < StandardError
        def initialize(path, cause)
          super("invalid machine metadata at #{path}: #{cause.message}")
        end
      end

      class UnsupportedHost < StandardError
        def initialize(host_platform)
          super(
            "AVF provider requires macOS on Apple Silicon. Detected #{host_platform.description}."
          )
        end
      end

      class MachineRequirementsChanged < StandardError
        def initialize(fields)
          super(
            "machine requirements changed for the existing machine (#{fields.join(', ')}). " \
            "Destroy and recreate the machine to apply those changes."
          )
        end
      end

      class MissingMachineState < StandardError
        def initialize
          super("read_state did not set :machine_state")
        end
      end

      class MissingBootArtifact < StandardError
        def initialize(path)
          super("required boot artifact does not exist: #{path}")
        end
      end

      class InvalidDiskImage < StandardError
        def initialize(path, message)
          super("invalid disk image at #{path}: #{message}")
        end
      end

      class AvfHelperBuildFailed < StandardError
        def initialize(message)
          super("failed to build the AVF helper: #{message}")
        end
      end

      class MachineStartFailed < StandardError
        def initialize(message)
          super("failed to start the AVF virtual machine: #{message}")
        end
      end

      class SshPortUnavailable < StandardError
        def initialize(message)
          super(message)
        end
      end

      class SshForwarderStartFailed < StandardError
        def initialize(message)
          super("failed to start SSH port forwarding: #{message}")
        end
      end

      class LinuxCloudInitSeedFailed < StandardError
        def initialize(message)
          super("failed to write the Linux cloud-init seed: #{message}")
        end
      end

      class MachineStopFailed < StandardError
        def initialize(message)
          super("failed to stop the AVF virtual machine: #{message}")
        end
      end

      class MachineDestroyFailed < StandardError
        def initialize(message)
          super("failed to destroy the AVF virtual machine: #{message}")
        end
      end

      class SyncedFoldersUnavailable < StandardError
        def initialize(message)
          super(message)
        end
      end

      class SyncedFolderMountFailed < StandardError
        def initialize(message)
          super("failed to mount an AVF shared directory: #{message}")
        end
      end
    end
  end
end
