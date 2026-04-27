module VagrantPlugins
  module AVF
    class SupportedLinuxBox
      DEFINITIONS = {
        "ubuntu" => {
          slug: "ubuntu-24.04-arm64",
          cloud_display_name: "Ubuntu 24.04",
          package_display_name: "Ubuntu",
          default_release: "24.04",
          default_disk_gb: nil,
          kernel_artifacts: true
        },
        "almalinux" => {
          slug: "almalinux-9-arm64",
          cloud_display_name: "AlmaLinux 9",
          package_display_name: "AlmaLinux",
          default_release: "9",
          default_disk_gb: 12,
          kernel_artifacts: false
        },
        "rocky" => {
          slug: "rocky-9-arm64",
          cloud_display_name: "Rocky Linux 9",
          package_display_name: "Rocky Linux",
          default_release: "9",
          default_disk_gb: 12,
          kernel_artifacts: false
        }
      }.freeze

      attr_reader :family

      def self.supported_families
        DEFINITIONS.keys
      end

      def self.fetch(family)
        definition = DEFINITIONS[family.to_s]
        raise ArgumentError, "#{family} is not a supported linux box family" if definition.nil?

        new(family.to_s, definition)
      end

      def self.for_box_name(box_name)
        slug = box_name.to_s.split("/", 2).last.to_s
        family = slug.split("-", 2).first
        supported_box = DEFINITIONS.key?(family) ? fetch(family) : nil
        return if supported_box.nil?
        return supported_box if supported_box.slug == slug
      end

      def initialize(family, definition)
        @family = family
        @definition = definition
      end

      def slug
        @definition.fetch(:slug)
      end

      def local_box_name
        "avf/#{slug}"
      end

      def cloud_display_name
        @definition.fetch(:cloud_display_name)
      end

      def default_release
        @definition.fetch(:default_release)
      end

      def default_disk_gb
        @definition.fetch(:default_disk_gb)
      end

      def kernel_artifacts?
        @definition.fetch(:kernel_artifacts)
      end

      def release_env_name
        "#{family.upcase}_RELEASE"
      end

      def package_description(release)
        "Minimal #{package_display_name} #{release} ARM64 base box for vagrant-provider-avf"
      end

      private

      def package_display_name
        @definition.fetch(:package_display_name)
      end
    end
  end
end
