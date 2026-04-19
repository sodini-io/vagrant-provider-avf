module VagrantPlugins
  module AVF
    module Model
      class BootConfig
        GUESTS = [:linux].freeze
        FIELDS = [:guest, :kernel_path, :initrd_path, :disk_image_path].freeze

        def self.from_h(attributes)
          new(
            guest: fetch(attributes, "guest"),
            kernel_path: fetch(attributes, "kernel_path"),
            initrd_path: fetch(attributes, "initrd_path"),
            disk_image_path: fetch(attributes, "disk_image_path")
          )
        end

        def self.fetch(attributes, key)
          return attributes[key] if attributes.key?(key)
          return attributes[key.to_sym] if attributes.key?(key.to_sym)

          nil
        end

        attr_reader :guest, :kernel_path, :initrd_path, :disk_image_path

        def initialize(guest:, kernel_path:, initrd_path:, disk_image_path:)
          @guest = normalize_guest(guest)
          @kernel_path = normalize_path(kernel_path)
          @initrd_path = normalize_path(initrd_path)
          @disk_image_path = normalize_path(disk_image_path)
        end

        def errors
          [].tap do |result|
            validate_guest(result)
            validate_path(:kernel_path, @kernel_path, result) if @kernel_path || @initrd_path
            validate_path(:initrd_path, @initrd_path, result) if @kernel_path || @initrd_path
            validate_path(:disk_image_path, @disk_image_path, result)
          end
        end

        def linux?
          @guest == :linux
        end

        def linux_kernel_boot?
          linux? && !@kernel_path.nil? && !@initrd_path.nil?
        end

        def linux_disk_boot?
          linux? && @kernel_path.nil? && @initrd_path.nil?
        end

        def changed_fields(other)
          FIELDS.select { |field| public_send(field) != other.public_send(field) }
        end

        def to_h
          {
            "guest" => @guest.to_s,
            "kernel_path" => @kernel_path,
            "initrd_path" => @initrd_path,
            "disk_image_path" => @disk_image_path
          }
        end

        private

        def normalize_guest(value)
          return :linux if value.nil?

          value.to_sym
        rescue NoMethodError
          value
        end

        def normalize_path(value)
          return if value.nil?

          path = value.to_s.strip
          path.empty? ? nil : path
        end

        def validate_guest(errors)
          return if GUESTS.include?(@guest)

          errors << "guest must be one of: #{GUESTS.join(', ')}"
        end

        def validate_path(name, path, errors)
          if path.nil?
            errors << "#{name} is required"
            return
          end

          return if path.start_with?("/")

          errors << "#{name} must be an absolute path"
        end

      end
    end
  end
end
