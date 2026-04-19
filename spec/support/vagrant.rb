module Vagrant
  class MachineState
    NOT_CREATED_ID = :not_created

    attr_reader :id, :short_description, :long_description

    def initialize(id, short, long)
      @id = id
      @short_description = short
      @long_description = long
    end
  end

  def self.plugin(version, component = nil)
    raise ArgumentError, "unsupported plugin version: #{version}" unless version.to_s == "2"

    case component
    when nil
      Plugin::V2::Plugin
    when :config
      Config::Base
    when :provider
      Plugin::V2::Provider
    when :synced_folder
      Plugin::V2::SyncedFolder
    else
      raise ArgumentError, "unsupported plugin component: #{component.inspect}"
    end
  end

  module Action
    class Builder
      def initialize
        @middleware = []
      end

      def use(klass, *args)
        @middleware << [klass, args]
      end

      def call(env)
        app = @middleware.reverse.inject(->(inner_env) { inner_env }) do |downstream, (klass, args)|
          ->(inner_env) { klass.new(downstream, inner_env, *args).call(inner_env) }
        end

        app.call(env)
      end
    end

    module Builtin
      class SyncedFolderCleanup
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:synced_folder_cleanup_called] = true
          @app.call(env)
        end
      end

      class SyncedFolders
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:synced_folders_called] = true
          @app.call(env)
        end
      end

      class WaitForCommunicator
        def initialize(app, _env, _states = nil)
          @app = app
        end

        def call(env)
          env[:wait_for_communicator_called] = true
          @app.call(env)
        end
      end

      class SSHExec
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:ssh_exec_called] = true
          @app.call(env)
        end
      end

      class SSHRun
        def initialize(app, _env)
          @app = app
        end

        def call(env)
          env[:ssh_run_called] = true
          @app.call(env)
        end
      end
    end
  end

  module Config
    class Base
      UNSET_VALUE = Object.new.freeze

      def _detected_errors
        []
      end
    end
  end

  module Plugin
    module V2
      class Plugin
        class << self
          attr_reader :plugin_name, :plugin_description, :registered_configs, :registered_providers
          attr_reader :registered_synced_folders

          def inherited(subclass)
            super
            subclass.instance_variable_set(:@registered_configs, {})
            subclass.instance_variable_set(:@registered_providers, {})
            subclass.instance_variable_set(:@registered_synced_folders, {})
          end

          def name(value = nil)
            return @plugin_name if value.nil?

            @plugin_name = value
          end

          def description(value = nil)
            return @plugin_description if value.nil?

            @plugin_description = value
          end

          def config(name, scope = nil, &block)
            @registered_configs[[name, scope]] = block.call
          end

          def provider(name, **_options, &block)
            @registered_providers[name.to_sym] = block.call
          end

          def synced_folder(name, _priority = 10, &block)
            @registered_synced_folders[name.to_sym] = block.call
          end
        end
      end

      class Provider
      end

      class SyncedFolder
      end
    end
  end
end
