require "socket"

module VagrantPlugins
  module AVF
    class PortAllocator
      DEFAULT_RANGE = (2222..2299)

      def initialize(host: "127.0.0.1", port_range: DEFAULT_RANGE, server_class: TCPServer)
        @host = host
        @port_range = port_range
        @server_class = server_class
      end

      def allocate(preferred_port: nil)
        return preferred_port if preferred_port && available?(preferred_port)
        raise Errors::SshPortUnavailable, "SSH forwarding port #{preferred_port} is unavailable" if preferred_port

        @port_range.each do |port|
          return port if available?(port)
        end

        raise Errors::SshPortUnavailable, "no available SSH forwarding ports in #{@port_range.begin}-#{@port_range.end}"
      end

      private

      def available?(port)
        server = @server_class.new(@host, port)
        server.close
        true
      rescue Errno::EADDRINUSE, Errno::EACCES
        false
      end
    end
  end
end
