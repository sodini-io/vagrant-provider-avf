module VagrantPlugins
  module AVF
    class Plugin < Vagrant.plugin("2")
      name "AVF Provider"
      description "Vagrant provider for Apple's Virtualization Framework (AVF) on Apple Silicon Macs."

      config("avf", :provider) do
        Config
      end

      provider(:avf) do
        Provider
      end

      synced_folder("avf_virtiofs", 15) do
        SyncedFolder
      end
    end
  end
end
