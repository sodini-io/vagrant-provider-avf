require_relative "supported_linux_box"

module VagrantPlugins
  module AVF
    class ReleaseTarget
      attr_reader :box_name

      def initialize(box_name)
        @box_name = box_name.to_s
      end

      def support_status
        return :supported unless supported_linux_box.nil?

        :unknown
      end

      def validate_publishable!
        return if support_status == :supported

        raise ArgumentError, publish_error_message
      end

      def supported_linux_box
        @supported_linux_box ||= SupportedLinuxBox.for_box_name(@box_name)
      end

      private

      def publish_error_message
        "#{@box_name} is not a supported release target"
      end
    end
  end
end
