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
        release_target.validate_publishable!
        self
      end

      def short_description
        "#{supported_linux_box.cloud_display_name} ARM64 for vagrant-provider-avf"
      end

      def description
        [
          "#{supported_linux_box.cloud_display_name} ARM64 base box for the avf provider on Apple Silicon Macs.",
          "Requires the vagrant-provider-avf plugin.",
          "Source and documentation: #{@repository_url}"
        ].join("\n\n")
      end

      private

      def release_target
        @release_target ||= ReleaseTarget.new(@box_name)
      end

      def supported_linux_box
        release_target.supported_linux_box || raise(ArgumentError, "#{@box_name} is not a supported release target")
      end
    end
  end
end
