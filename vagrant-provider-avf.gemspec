require_relative "lib/vagrant_provider_avf/version"

Gem::Specification.new do |spec|
  spec.name = "vagrant-provider-avf"
  spec.version = VagrantPlugins::AVF::VERSION
  spec.summary = "Vagrant provider for AVF on Apple Silicon Macs"
  spec.description = "A lean Vagrant provider for Apple Silicon Macs using Apple's Virtualization Framework (AVF)."
  spec.authors = ["Contributors"]
  spec.license = "MIT"
  spec.files = Dir["lib/**/*", "LICENSE", "NOTICE", "README.md"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.6"

  spec.add_development_dependency "rspec", "~> 3.13"
end
