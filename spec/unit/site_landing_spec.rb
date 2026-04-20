require "spec_helper"

RSpec.describe "GitHub Pages landing site" do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:index_html) { File.read(File.join(repo_root, "docs/index.html")) }
  let(:site_css_path) { File.join(repo_root, "docs/site.css") }
  let(:nojekyll_path) { File.join(repo_root, "docs/.nojekyll") }

  it "ships a landing page for the supported public project surface" do
    expect(index_html).to include("Vagrant, native on Apple Silicon.")
    expect(index_html).to include("sodini-io/ubuntu-24.04-arm64")
    expect(index_html).to include("sodini-io/almalinux-9-arm64")
    expect(index_html).to include("sodini-io/rocky-9-arm64")
    expect(index_html).to include("vagrant plugin install vagrant-provider-avf")
  end

  it "includes the static assets needed for docs-based GitHub Pages publishing" do
    expect(File).to exist(site_css_path)
    expect(File).to exist(nojekyll_path)
  end
end
