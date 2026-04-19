require "spec_helper"

RSpec.describe "vagrant-provider-avf.gemspec" do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:gemspec_path) { File.join(repo_root, "vagrant-provider-avf.gemspec") }
  let(:specification) { Gem::Specification.load(gemspec_path) }

  it "declares the RubyGems metadata needed for public release" do
    expect(specification.name).to eq("vagrant-provider-avf")
    expect(specification.authors).to eq(["James Sodini"])
    expect(specification.email).to eq(["james@sodini.io"])
    expect(specification.homepage).to eq("https://github.com/sodini-io/vagrant-provider-avf")
    expect(specification.metadata.fetch("source_code_uri")).to eq("https://github.com/sodini-io/vagrant-provider-avf")
    expect(specification.metadata.fetch("homepage_uri")).to eq("https://github.com/sodini-io/vagrant-provider-avf")
    expect(specification.metadata.fetch("documentation_uri")).to eq("https://github.com/sodini-io/vagrant-provider-avf#readme")
    expect(specification.metadata.fetch("bug_tracker_uri")).to eq("https://github.com/sodini-io/vagrant-provider-avf/issues")
    expect(specification.metadata.fetch("changelog_uri")).to eq("https://github.com/sodini-io/vagrant-provider-avf/releases")
    expect(specification.metadata.fetch("allowed_push_host")).to eq("https://rubygems.org")
    expect(specification.metadata.fetch("rubygems_mfa_required")).to eq("true")
  end
end
