require "rbconfig"

module VagrantPlugins
  module AVF
    class HostPlatform
      attr_reader :os, :cpu

      def self.current
        new(
          os: RbConfig::CONFIG.fetch("host_os"),
          cpu: RbConfig::CONFIG.fetch("host_cpu")
        )
      end

      def initialize(os:, cpu:)
        @os = os
        @cpu = cpu
      end

      def supported?
        macos? && apple_silicon?
      end

      def description
        "#{@os}/#{@cpu}"
      end

      private

      def macos?
        @os.include?("darwin")
      end

      def apple_silicon?
        @cpu == "arm64" || @cpu == "aarch64"
      end
    end
  end
end
