require "spec_helper"

RSpec.describe "README quickstart" do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:readme) { File.read(File.join(repo_root, "README.md")) }

  it "keeps the top-level readme focused on getting started" do
    expect(readme).to include("## Quickstart")
    expect(readme).to include("vagrant plugin install vagrant-provider-avf")
    expect(readme).to include('config.vm.box = "avf/ubuntu-24.04-arm64"')
    expect(readme).to include('config.vm.box = "avf/almalinux-9-arm64"')
    expect(readme).to include('config.vm.box = "avf/rocky-9-arm64"')
    expect(readme).to include("[docs/project-scope.md]")
  end
end
