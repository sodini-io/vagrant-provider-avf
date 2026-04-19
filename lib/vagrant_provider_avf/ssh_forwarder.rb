require "json"
require "pathname"
require "rbconfig"

module VagrantPlugins
  module AVF
    class SshForwarder
      START_TIMEOUT_SECONDS = 2
      POLL_INTERVAL_SECONDS = 0.05

      def initialize(machine_data_dir:, process_control: ProcessControl.new, ruby_path: RbConfig.ruby)
        @machine_data_dir = Pathname.new(machine_data_dir)
        @process_control = process_control
        @ruby_path = ruby_path
      end

      def start(listen_port:, target_host:, target_port:)
        cleanup_files
        write_request(listen_port, target_host, target_port)

        process_id = @process_control.spawn(
          [@ruby_path, runner_path.to_s, request_path.to_s],
          out: log_path.to_s,
          err: log_path.to_s
        )

        wait_for_start(process_id)
        process_id
      rescue Errors::SshForwarderStartFailed
        raise
      rescue StandardError => error
        raise Errors::SshForwarderStartFailed, error.message
      end

      def alive?(process_id)
        process_id && @process_control.alive?(process_id)
      end

      def stop(process_id)
        return unless process_id

        @process_control.stop(process_id, timeout: START_TIMEOUT_SECONDS)
      end

      def cleanup_files
        [request_path, ready_path, error_path, log_path].each do |path|
          path.delete if path.exist?
        end
      end

      private

      def write_request(listen_port, target_host, target_port)
        request_path.write(JSON.dump(request_payload(listen_port, target_host, target_port)))
      end

      def request_payload(listen_port, target_host, target_port)
        {
          "listen_host" => "127.0.0.1",
          "listen_port" => listen_port,
          "target_host" => target_host,
          "target_port" => target_port,
          "ready_path" => ready_path.to_s,
          "error_path" => error_path.to_s
        }
      end

      def wait_for_start(process_id)
        deadline = Time.now + START_TIMEOUT_SECONDS

        loop do
          return if ready_path.exist?
          raise error_message if error_path.exist? && !error_path.size.zero?
          raise Errors::SshForwarderStartFailed, "the SSH forwarder exited before reporting readiness" unless @process_control.alive?(process_id)
          raise Errors::SshForwarderStartFailed, "timed out waiting for the SSH forwarder to start" if Time.now >= deadline

          sleep(POLL_INTERVAL_SECONDS)
        end
      end

      def error_message
        message = error_path.read.strip
        message.empty? ? "the SSH forwarder reported an unknown error" : message
      end

      def runner_path
        Pathname.new(File.expand_path("driver/ssh_forwarder_runner.rb", __dir__))
      end

      def request_path
        @machine_data_dir.join("ssh-forwarder-request.json")
      end

      def ready_path
        @machine_data_dir.join("ssh-forwarder-ready")
      end

      def error_path
        @machine_data_dir.join("ssh-forwarder-error.txt")
      end

      def log_path
        @machine_data_dir.join("ssh-forwarder.log")
      end
    end
  end
end
