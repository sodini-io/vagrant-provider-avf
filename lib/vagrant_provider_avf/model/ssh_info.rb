module VagrantPlugins
  module AVF
    module Model
      class SshInfo
        attr_reader :host, :port, :username

        def self.from_h(attributes)
          new(
            host: fetch_required(attributes, "host"),
            port: fetch_required(attributes, "port"),
            username: fetch_required(attributes, "username")
          )
        end

        def self.fetch_required(attributes, key)
          value = attributes[key] || attributes[key.to_sym]
          raise ArgumentError, "#{key} is required" if value.nil? || value == ""

          value
        end

        def initialize(host:, port:, username:)
          @host = normalize_host(host)
          @port = normalize_port(port)
          @username = normalize_username(username)
        end

        def to_h
          {
            host: @host,
            port: @port,
            username: @username
          }
        end

        private

        def normalize_host(host)
          value = host.to_s
          raise ArgumentError, "host is required" if value.empty?

          value
        end

        def normalize_port(port)
          return port if port.is_a?(Integer) && port.positive?
          return port.to_i if port.is_a?(String) && port.match?(/\A\d+\z/) && port.to_i.positive?

          raise ArgumentError, "port must be a positive integer"
        end

        def normalize_username(username)
          value = username.to_s
          raise ArgumentError, "username is required" if value.empty?

          value
        end
      end
    end
  end
end
