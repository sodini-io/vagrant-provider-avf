module VagrantPlugins
  module AVF
    class ReleaseTarget
      SUPPORTED_FAMILIES = ["ubuntu", "almalinux", "rocky"].freeze

      attr_reader :box_name

      def initialize(box_name)
        @box_name = box_name.to_s
      end

      def support_status
        return :supported if SUPPORTED_FAMILIES.include?(family)

        :unknown
      end

      def validate_publishable!
        return if support_status == :supported

        raise ArgumentError, publish_error_message
      end

      private

      def family
        slug.split("-", 2).first
      end

      def slug
        @box_name.split("/", 2).last.to_s
      end

      def publish_error_message
        "#{@box_name} is not a supported release target"
      end
    end
  end
end
