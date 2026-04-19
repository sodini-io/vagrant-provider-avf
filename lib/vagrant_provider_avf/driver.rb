require "digest"
require "fileutils"
require "json"
require "securerandom"
require "socket"

module VagrantPlugins
  module AVF
    class Driver
      START_TIMEOUT_SECONDS = 10
      STOP_TIMEOUT_SECONDS = 10
      POLL_INTERVAL_SECONDS = 0.1
      SSH_INFO_MARKER = "__AVF_SSH_INFO__ ".freeze

      def initialize(
        machine_metadata_store:,
        machine_data_dir:,
        machine_id_generator: -> { SecureRandom.uuid },
        process_control: ProcessControl.new,
        helper_installer: nil,
        linux_cloud_init_seed: LinuxCloudInitSeed.new(machine_data_dir: machine_data_dir),
        dhcp_leases: DhcpLeases.new,
        port_allocator: PortAllocator.new,
        ssh_forwarder: nil
      )
        @machine_metadata_store = machine_metadata_store
        @paths = DriverPaths.new(machine_data_dir)
        @machine_id_generator = machine_id_generator
        @process_control = process_control
        @helper_installer = helper_installer || HelperInstaller.new(paths: @paths)
        @linux_cloud_init_seed = linux_cloud_init_seed
        @dhcp_leases = dhcp_leases
        @port_allocator = port_allocator
        @ssh_forwarder = ssh_forwarder || SshForwarder.new(
          machine_data_dir: machine_data_dir,
          process_control: process_control
        )
      end

      def fetch(machine_id)
        return if blank?(machine_id)

        @machine_metadata_store.fetch(machine_id: machine_id)
      end

      def read_state(machine_id)
        metadata = fetch(machine_id)
        return unless metadata

        return metadata.state unless metadata.running?
        return :running if alive?(metadata.process_id)

        restore_stopped_machine(metadata).state
      end

      def read_ssh_info(machine_id)
        metadata = fetch(machine_id)
        return unless metadata && metadata.running?

        unless alive?(metadata.process_id)
          restore_stopped_machine(metadata)
          return
        end
        return metadata.ssh_info if ssh_info_available?(metadata)

        guest_ssh_info = discover_guest_ssh_info(metadata)
        return unless guest_ssh_info

        persist_ssh_info(metadata, guest_ssh_info)
      end

      def create(machine_requirements, boot_config, machine_id: nil)
        metadata = Model::MachineMetadata.stopped(
          machine_id || "avf-#{@machine_id_generator.call}",
          machine_requirements: machine_requirements,
          boot_config: boot_config,
          ssh_port: @port_allocator.allocate
        )

        @machine_metadata_store.save(metadata)
        metadata
      end

      def start(machine_id, machine_requirements:, boot_config:, shared_directories: [])
        validate_machine_requirements!(machine_requirements)
        ensure_boot_artifacts!(boot_config)
        helper_path = install_helper
        runtime_disk_path = prepare_disk_image(boot_config.disk_image_path, machine_requirements.disk_gb)
        seed_image_path = prepare_guest_runtime(machine_id, boot_config)
        clean_start_files
        write_start_request(
          start_request(
            machine_id,
            machine_requirements,
            boot_config,
            runtime_disk_path,
            shared_directories: shared_directories,
            seed_image_path: seed_image_path,
            efi_variable_store_path: @paths.efi_variable_store_path_for(boot_config)
          )
        )

        process_id = spawn_helper(helper_path)
        started = wait_for_start(process_id)
        save_running_machine(machine_id, started, machine_requirements, boot_config)
      end

      def stop(machine_id)
        return if blank?(machine_id)

        metadata = fetch(machine_id)
        return if metadata.nil?
        return metadata unless metadata.running?

        stop_ssh_forwarder(metadata)
        @process_control.stop(metadata.process_id, timeout: STOP_TIMEOUT_SECONDS) if metadata.process_id

        save_stopped_machine(metadata)
      rescue StandardError => error
        raise Errors::MachineStopFailed, error.message
      end

      def destroy(machine_id)
        stop(machine_id) unless blank?(machine_id)
        @machine_metadata_store.clear
        cleanup_runtime_files
        nil
      rescue Errors::MachineStopFailed
        raise
      rescue StandardError => error
        raise Errors::MachineDestroyFailed, error.message
      end

      private

      def alive?(process_id)
        process_id && @process_control.alive?(process_id)
      end

      def validate_machine_requirements!(machine_requirements)
        return if machine_requirements.headless

        raise Errors::UnsupportedRuntimeConfiguration, "the current AVF boot slice supports headless=true only"
      end

      def prepare_guest_runtime(machine_id, boot_config)
        return prepare_linux_runtime(machine_id) if boot_config.linux_disk_boot?

        nil
      end

      def prepare_linux_runtime(machine_id)
        @linux_cloud_init_seed.write(
          machine_id: machine_id,
          mac_address: network_mac_address(machine_id)
        )
      end

      def ensure_boot_artifacts!(boot_config)
        paths = [boot_config.disk_image_path]
        paths.unshift(boot_config.kernel_path, boot_config.initrd_path) if boot_config.linux_kernel_boot?

        paths.compact.each do |path|
          raise Errors::MissingBootArtifact, path unless File.exist?(path)
        end
      end

      def prepare_disk_image(source_path, disk_gb)
        target_path = @paths.runtime_disk_path
        return target_path if target_path.exist?

        target_path.dirname.mkpath
        FileUtils.cp(source_path, target_path)
        target_size = disk_gb * 1024 * 1024 * 1024
        source_size = target_path.size
        raise Errors::InvalidDiskImage.new(source_path, "source image is larger than configured disk_gb") if source_size > target_size

        File.open(target_path, "ab") { |file| file.truncate(target_size) } if source_size < target_size
        target_path
      end

      def write_start_request(request)
        @paths.start_request_path.write(JSON.dump(request))
      end

      def spawn_helper(helper_path)
        @process_control.spawn(
          [helper_path.to_s, @paths.start_request_path.to_s],
          out: @paths.helper_log_path.to_s,
          err: @paths.helper_log_path.to_s
        )
      end

      def wait_for_start(process_id)
        deadline = Time.now + START_TIMEOUT_SECONDS

        loop do
          return JSON.parse(@paths.started_path.read) if @paths.started_path.exist? && !@paths.started_path.size.zero?
          raise Errors::MachineStartFailed, helper_error_message if @paths.error_path.exist? && !@paths.error_path.size.zero?
          raise Errors::MachineStartFailed, "the AVF helper exited before reporting a successful start" unless @process_control.alive?(process_id)
          raise Errors::MachineStartFailed, "timed out waiting for the AVF virtual machine to start" if Time.now >= deadline

          sleep(POLL_INTERVAL_SECONDS)
        end
      end

      def helper_error_message
        message = @paths.error_path.read.strip
        message.empty? ? "the AVF helper reported an unknown error" : message
      end

      def start_request(machine_id, machine_requirements, boot_config, disk_path, shared_directories:, seed_image_path:, efi_variable_store_path:)
        DriverStartRequest.new(
          machine_id: machine_id,
          machine_requirements: machine_requirements,
          boot_config: boot_config,
          disk_path: disk_path,
          mac_address: network_mac_address(machine_id),
          shared_directories: shared_directories,
          seed_image_path: seed_image_path,
          efi_variable_store_path: efi_variable_store_path,
          paths: @paths
        ).to_h
      end

      def stopped_metadata_for(metadata)
        Model::MachineMetadata.stopped(
          metadata.machine_id,
          guest_ssh_info: metadata.guest_ssh_info,
          machine_requirements: metadata.machine_requirements,
          boot_config: metadata.boot_config,
          ssh_port: metadata.ssh_port
        )
      end

      def save_stopped_machine(metadata)
        stopped_metadata = stopped_metadata_for(metadata)
        @machine_metadata_store.save(stopped_metadata)
        stopped_metadata
      end

      def running_metadata_with_ssh_info(metadata, guest_ssh_info, ssh_info, ssh_port:, ssh_forwarder_process_id:)
        Model::MachineMetadata.running(
          metadata.machine_id,
          process_id: metadata.process_id,
          ssh_info: ssh_info,
          guest_ssh_info: guest_ssh_info,
          machine_requirements: metadata.machine_requirements,
          boot_config: metadata.boot_config,
          ssh_port: ssh_port,
          ssh_forwarder_process_id: ssh_forwarder_process_id
        )
      end

      def ssh_info_available?(metadata)
        metadata.ssh_info && @ssh_forwarder.alive?(metadata.ssh_forwarder_process_id)
      end

      def ssh_port_for(metadata)
        @port_allocator.allocate(preferred_port: metadata.ssh_port)
      end

      def start_ssh_forwarder(ssh_port, guest_ssh_info)
        @ssh_forwarder.start(
          listen_port: ssh_port,
          target_host: guest_ssh_info.host,
          target_port: guest_ssh_info.port
        )
      end

      def forwarded_ssh_info(ssh_port, username)
        Model::SshInfo.new(
          host: "127.0.0.1",
          port: ssh_port,
          username: username
        )
      end

      def save_running_machine(machine_id, started, machine_requirements, boot_config)
        previous_metadata = fetch(machine_id)
        metadata = Model::MachineMetadata.running(
          machine_id,
          process_id: started.fetch("process_id"),
          ssh_info: started["ssh_info"],
          guest_ssh_info: started["ssh_info"] || previous_metadata&.guest_ssh_info,
          machine_requirements: machine_requirements,
          boot_config: boot_config,
          ssh_port: previous_metadata&.ssh_port
        )
        @machine_metadata_store.save(metadata)
        metadata
      end

      def restore_stopped_machine(metadata)
        stop_ssh_forwarder(metadata)
        save_stopped_machine(metadata)
      end

      def stop_ssh_forwarder(metadata)
        return unless metadata&.ssh_forwarder_process_id

        @ssh_forwarder.stop(metadata.ssh_forwarder_process_id)
      end

      def read_console_ssh_info
        return unless @paths.console_log_path.exist? && !@paths.console_log_path.size.zero?

        ssh_info = nil
        File.foreach(@paths.console_log_path) do |line|
          parsed = parse_console_ssh_info(line)
          ssh_info = parsed if parsed
        end

        ssh_info
      end

      def discover_guest_ssh_info(metadata)
        reused_guest_ssh_info(metadata) ||
          read_console_ssh_info ||
          read_dhcp_ssh_info(metadata)
      end

      def reused_guest_ssh_info(metadata)
        ssh_info = metadata.guest_ssh_info
        return if ssh_info.nil?
        return unless ssh_port_open?(ssh_info.host, ssh_info.port)

        ssh_info
      end

      def read_dhcp_ssh_info(metadata)
        ip_address = @dhcp_leases.ip_address_for(mac_address: network_mac_address(metadata.machine_id))
        return if blank?(ip_address)
        return unless ssh_port_open?(ip_address, 22)

        Model::SshInfo.new(
          host: ip_address,
          port: 22,
          username: "vagrant"
        )
      end

      def persist_ssh_info(metadata, guest_ssh_info)
        ssh_port = ssh_port_for(metadata)
        forwarder_process_id = start_ssh_forwarder(ssh_port, guest_ssh_info)
        ssh_info = forwarded_ssh_info(ssh_port, guest_ssh_info.username)
        updated_metadata = running_metadata_with_ssh_info(
          metadata,
          guest_ssh_info,
          ssh_info,
          ssh_port: ssh_port,
          ssh_forwarder_process_id: forwarder_process_id
        )
        @machine_metadata_store.save(updated_metadata)
        ssh_info
      end

      def parse_console_ssh_info(line)
        return unless line.include?(SSH_INFO_MARKER)

        payload = line.split(SSH_INFO_MARKER, 2).last.to_s.strip
        return if payload.empty?

        Model::SshInfo.from_h(JSON.parse(payload))
      rescue JSON::ParserError, ArgumentError, KeyError
        nil
      end

      def ssh_port_open?(host, port)
        Socket.tcp(host, port, connect_timeout: 0.5) do |socket|
          socket.close
          return true
        end
      rescue StandardError
        false
      end

      def network_mac_address(machine_id)
        digest = Digest::SHA256.hexdigest(machine_id.to_s)
        ["02", *5.times.map { |index| digest[index * 2, 2] }].join(":")
      end

      def install_helper
        return @helper_installer.call if @helper_installer.respond_to?(:call)

        @helper_installer.install
      end

      def clean_start_files
        [@paths.start_request_path, @paths.started_path, @paths.error_path].each do |path|
          path.delete if path.exist?
        end
      end

      def cleanup_runtime_files
        @paths.cleanup_paths(linux_cloud_init_seed_path: @linux_cloud_init_seed.path).each do |path|
          path.delete if path.exist?
        end
        @ssh_forwarder.cleanup_files
      end

      def blank?(value)
        value.nil? || value == ""
      end
    end
  end
end
