require "shellwords"

module VagrantPlugins
  module AVF
    class SyncedFolder < Vagrant.plugin("2", :synced_folder)
      SHARED_DIRECTORIES_ROOT = "/run/avf-shares".freeze

      def usable?(machine, raise_error = false)
        return true if linux_avf_machine?(machine)
        return false unless raise_error

        raise Errors::SyncedFoldersUnavailable,
          "AVF shared directories currently support provider=:avf with guest=:linux only"
      end

      def prepare(_machine, _folders, _opts)
      end

      def enable(machine, folders, _opts)
        mount_shared_root(machine)
        folders.each do |id, data|
          mount_shared_directory(machine, id, data[:guestpath])
        end
      rescue StandardError => error
        raise Errors::SyncedFolderMountFailed, error.message
      end

      def disable(machine, folders, _opts)
        folders.each_value do |data|
          guest_path = Shellwords.escape(data[:guestpath])
          machine.communicate.sudo("mountpoint -q #{guest_path} && umount #{guest_path} || true")
        end
        shared_root = Shellwords.escape(SHARED_DIRECTORIES_ROOT)
        machine.communicate.sudo("mountpoint -q #{shared_root} && umount #{shared_root} || true")
      end

      def cleanup(_machine, _opts)
      end

      private

      def linux_avf_machine?(machine)
        machine.provider_name == :avf && machine.provider_config.boot_config.linux?
      end

      def mount_shared_root(machine)
        escaped_root = Shellwords.escape(SHARED_DIRECTORIES_ROOT)
        escaped_tag = Shellwords.escape(Model::SharedDirectory::DEVICE_TAG)

        machine.communicate.sudo("mkdir -p #{escaped_root}")
        machine.communicate.sudo(
          "mountpoint -q #{escaped_root} || mount -t virtiofs #{escaped_tag} #{escaped_root}"
        )
      end

      def mount_shared_directory(machine, id, guest_path)
        escaped_guest_path = Shellwords.escape(guest_path)
        escaped_source = Shellwords.escape(File.join(SHARED_DIRECTORIES_ROOT, Model::SharedDirectory.name_for(id)))

        machine.communicate.sudo("mkdir -p #{escaped_guest_path}")
        machine.communicate.sudo(
          "mountpoint -q #{escaped_guest_path} || mount --bind #{escaped_source} #{escaped_guest_path}"
        )
      end
    end
  end
end
