module VagrantPlugins
  module AVF
    module Action
      def self.action_ssh
        Vagrant::Action::Builder.new.tap do |builder|
          builder.use(Vagrant::Action::Builtin::SSHExec)
        end
      end

      def self.action_ssh_run
        Vagrant::Action::Builder.new.tap do |builder|
          builder.use(Vagrant::Action::Builtin::SSHRun)
        end
      end
    end
  end
end
