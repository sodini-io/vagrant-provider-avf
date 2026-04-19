require "digest"

module VagrantPlugins
  module AVF
    module Model
      class SharedDirectory
        DEVICE_TAG = "avfshare".freeze

        attr_reader :id, :host_path, :guest_path, :name

        def initialize(id:, host_path:, guest_path:, name: nil)
          @id = id.to_s
          @host_path = host_path.to_s
          @guest_path = guest_path.to_s
          @name = name || self.class.name_for(id)
        end

        def to_h
          {
            "hostPath" => @host_path,
            "name" => @name,
            "readOnly" => false
          }
        end

        def self.name_for(id)
          "share-#{Digest::SHA256.hexdigest(id.to_s)[0, 12]}"
        end
      end
    end
  end
end
