module VagrantPlugins
  module AVF
    module Model
      class MachineRequirements
        DEFAULT_CPUS = 1
        DEFAULT_MEMORY_MB = 1024
        DEFAULT_DISK_GB = 16
        FIELDS = [:cpus, :memory_mb, :disk_gb, :headless].freeze

        def self.from_h(attributes)
          new(
            cpus: fetch(attributes, "cpus"),
            memory_mb: fetch(attributes, "memory_mb"),
            disk_gb: fetch(attributes, "disk_gb"),
            headless: fetch(attributes, "headless")
          )
        end

        def self.fetch(attributes, key)
          return attributes[key] if attributes.key?(key)
          return attributes[key.to_sym] if attributes.key?(key.to_sym)

          nil
        end

        attr_reader :cpus, :memory_mb, :disk_gb, :headless

        def initialize(cpus:, memory_mb:, disk_gb:, headless:)
          @cpus = normalize_integer(cpus, DEFAULT_CPUS)
          @memory_mb = normalize_integer(memory_mb, DEFAULT_MEMORY_MB)
          @disk_gb = normalize_integer(disk_gb, DEFAULT_DISK_GB)
          @headless = headless.nil? ? true : headless
        end

        def errors
          [].tap do |result|
            validate_positive_integer(:cpus, @cpus, result)
            validate_positive_integer(:memory_mb, @memory_mb, result)
            validate_positive_integer(:disk_gb, @disk_gb, result)
            validate_boolean(:headless, @headless, result)
          end
        end

        def changed_fields(other)
          FIELDS.select { |field| public_send(field) != other.public_send(field) }
        end

        def to_h
          {
            "cpus" => @cpus,
            "memory_mb" => @memory_mb,
            "disk_gb" => @disk_gb,
            "headless" => @headless
          }
        end

        private

        def normalize_integer(value, default)
          return default if value.nil?
          return value if value.is_a?(Integer)
          return value.to_i if value.is_a?(String) && value.match?(/\A[+-]?\d+\z/)

          value
        end

        def validate_positive_integer(name, value, errors)
          unless value.is_a?(Integer)
            errors << "#{name} must be an integer"
            return
          end

          return if value.positive?

          errors << "#{name} must be greater than 0"
        end

        def validate_boolean(name, value, errors)
          return if value == true || value == false

          errors << "#{name} must be true or false"
        end
      end
    end
  end
end
