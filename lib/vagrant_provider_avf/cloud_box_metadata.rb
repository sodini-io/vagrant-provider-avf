require_relative "release_target"

module VagrantPlugins
  module AVF
    class CloudBoxMetadata
      REPOSITORY_URL = "https://github.com/sodini-io/vagrant-provider-avf".freeze

      attr_reader :box_name

      def initialize(box_name, repository_url: REPOSITORY_URL)
        @box_name = box_name.to_s
        @repository_url = repository_url
      end

      def validate!
        ReleaseTarget.new(@box_name).validate_publishable!
        self
      end

      def short_description
        "#{display_name} ARM64 for vagrant-provider-avf"
      end

      def description
        [
          "Curated #{display_name} ARM64 base box for the avf provider on Apple Silicon Macs.",
          "Requires the vagrant-provider-avf plugin.",
          "Source and documentation: #{@repository_url}"
        ].join("\n\n")
      end

      private

      def display_name
        case family
        when "ubuntu" then "Ubuntu 24.04"
        when "almalinux" then "AlmaLinux 9"
        when "rocky" then "Rocky Linux 9"
        else raise ArgumentError, "#{@box_name} is not a supported release target"
        end
      end

      def family
        @box_name.split("/", 2).last.to_s.split("-", 2).first
      end
    end
  end
end
