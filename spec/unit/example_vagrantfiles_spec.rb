require "spec_helper"

RSpec.describe "example Vagrantfiles" do
  let(:examples_root) { Pathname.new(File.expand_path("../../examples", __dir__)) }

  def compile(path)
    RubyVM::InstructionSequence.compile_file(path.to_s)
  end

  it "keeps the example Vagrantfiles syntactically valid" do
    examples = examples_root.glob("*/Vagrantfile").sort

    expect(examples).not_to be_empty
    examples.each { |path| expect { compile(path) }.not_to raise_error }
  end

  it "documents the supported Linux box flows" do
    expect(examples_root.join("ubuntu-minimal/Vagrantfile").read).to include('config.vm.box = "avf/ubuntu-24.04-arm64"')
    expect(examples_root.join("almalinux/Vagrantfile").read).to include("avf.disk_gb = 12")
    expect(examples_root.join("rocky/Vagrantfile").read).to include("avf.disk_gb = 12")
  end

  it "keeps every example self-describing about which box it targets" do
    examples_root.glob("*/Vagrantfile").sort.each do |path|
      expect(path.read).to match(/config\.vm\.box\s*=\s*"[^"]+"/)
    end
  end

  it "documents the Linux shared-folder feature surface" do
    content = examples_root.join("shared-folders/Vagrantfile").read

    expect(content).to include('config.vm.synced_folder ".", "/vagrant"')
    expect(content).to include('config.vm.synced_folder "examples", "/home/vagrant/examples", type: :avf_virtiofs')
    expect(content).to include("avf.headless = true")
  end
end
