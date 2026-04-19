module TestSupport
  class TestMachine
    attr_accessor :id
    attr_reader :provider_config, :data_dir, :config, :env, :provider_name, :communicate

    def initialize(provider_config:, data_dir:, id: nil, synced_folders: {}, root_path: nil, provider_name: :avf, communicate: nil)
      @provider_config = provider_config
      @data_dir = data_dir
      @id = id
      @provider_name = provider_name
      @communicate = communicate
      @config = Struct.new(:vm).new(Struct.new(:synced_folders).new(synced_folders))
      @env = Struct.new(:root_path).new(root_path || data_dir)
    end

    def bind(provider)
      @provider = provider
      self
    end

    def action(name, **options)
      @provider.action(name).call({ machine: self }.merge(options))
    end
  end
end
