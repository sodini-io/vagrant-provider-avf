module VagrantPlugins
  module AVF
    class DhcpLeases
      DEFAULT_PATH = "/private/var/db/dhcpd_leases".freeze

      def initialize(path: DEFAULT_PATH)
        @path = path
      end

      def ip_address_for(mac_address:)
        return unless File.file?(@path)

        normalized_mac_address = normalize(mac_address)
        entries.reverse_each do |entry|
          next unless matches_mac_address?(entry, normalized_mac_address)

          ip_address = entry["ip_address"]
          return ip_address unless blank?(ip_address)
        end

        nil
      end

      private

      def entries
        current = nil

        File.readlines(@path, chomp: true).each_with_object([]) do |line, parsed|
          stripped = line.strip
          if stripped == "{"
            current = {}
            next
          end

          if stripped == "}"
            parsed << current if current
            current = nil
            next
          end

          next unless current

          key, value = stripped.split("=", 2)
          next if blank?(key) || blank?(value)

          current[key] = value
        end
      end

      def matches_mac_address?(entry, normalized_mac_address)
        [entry["hw_address"], entry["identifier"]].compact.any? do |value|
          normalize(value).end_with?(normalized_mac_address)
        end
      end

      def normalize(value)
        value.to_s.downcase.gsub(/[^0-9a-f]/, "")
      end

      def blank?(value)
        value.nil? || value.empty?
      end
    end
  end
end
