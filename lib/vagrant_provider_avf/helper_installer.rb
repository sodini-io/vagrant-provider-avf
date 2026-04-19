require "open3"

module VagrantPlugins
  module AVF
    class HelperInstaller
      def initialize(paths:, command_runner: ->(*command) { Open3.capture3(*command) })
        @paths = paths
        @command_runner = command_runner
      end

      def install
        @paths.helper_binary_path.dirname.mkpath
        return @paths.helper_binary_path if up_to_date?

        build
        sign
        @paths.helper_binary_path
      rescue StandardError => error
        raise Errors::AvfHelperBuildFailed, error.message
      end

      private

      def up_to_date?
        @paths.helper_binary_path.exist? &&
          @paths.helper_binary_path.mtime >= @paths.helper_source_path.mtime
      end

      def build
        run_command("xcrun", "swiftc", @paths.helper_source_path.to_s, "-o", @paths.helper_binary_path.to_s)
      end

      def sign
        run_command(
          "codesign",
          "-f",
          "-s",
          "-",
          "--entitlements",
          @paths.helper_entitlements_path.to_s,
          @paths.helper_binary_path.to_s
        )
      end

      def run_command(*command)
        _stdout, stderr, status = @command_runner.call(*command)
        return if status.success?

        raise stderr.strip.empty? ? command.join(" ") : stderr.strip
      end
    end
  end
end
