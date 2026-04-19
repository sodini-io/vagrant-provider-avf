module VagrantPlugins
  module AVF
    class ProcessControl
      def spawn(command, out:, err:)
        Process.spawn(*command, in: File::NULL, out: out, err: err, pgroup: true)
      end

      def alive?(process_id)
        Process.kill(0, process_id)
        true
      rescue Errno::ESRCH
        false
      end

      def stop(process_id, timeout:)
        return unless alive?(process_id)

        Process.kill("TERM", process_id)
        deadline = Time.now + timeout
        sleep(0.1) while alive?(process_id) && Time.now < deadline

        return reap(process_id) unless alive?(process_id)

        Process.kill("KILL", process_id)
        reap(process_id)
      end

      private

      def reap(process_id)
        Process.wait(process_id)
      rescue Errno::ECHILD
        nil
      end
    end
  end
end
