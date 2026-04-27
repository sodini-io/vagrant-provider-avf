require "open3"
require "spec_helper"

RSpec.describe "published example workflow", :published_acceptance do
  it "verifies the published example Vagrantfiles against the released plugin and boxes" do
    org_slug = ENV.fetch("AVF_BOX_ORG", "sodini-io")
    box_version = ENV.fetch("AVF_BOX_VERSION", "0.1.0")
    command = [
      File.expand_path("../../scripts/ci-published-examples", __dir__),
      org_slug,
      box_version
    ]

    stdout, stderr, status = Open3.capture3(*command)

    expect(status.success?).to be(true), <<~MESSAGE
      published example acceptance workflow failed
      stdout:
      #{stdout}

      stderr:
      #{stderr}
    MESSAGE
    expect(stdout).to include("verified example plugin install provides vagrant-provider-avf")
    expect(stdout).to include("verified example Vagrantfile rewrites avf/ubuntu-24.04-arm64 to #{org_slug}/ubuntu-24.04-arm64")
    expect(stdout).to include("verified example Vagrantfile rewrites avf/almalinux-9-arm64 to #{org_slug}/almalinux-9-arm64")
    expect(stdout).to include("verified example Vagrantfile rewrites avf/rocky-9-arm64 to #{org_slug}/rocky-9-arm64")
    expect(stdout).to include("verified shared-folders example writes through both guest mounts after restart")
  end
end
