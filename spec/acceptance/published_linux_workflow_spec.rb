require "open3"
require "spec_helper"

RSpec.describe "published linux workflow", :published_acceptance do
  it "verifies the clean-home published plugin and box path across the supported linux matrix" do
    org_slug = ENV.fetch("AVF_BOX_ORG", "sodini-io")
    box_version = ENV.fetch("AVF_BOX_VERSION", "0.1.0")
    command = [
      File.expand_path("../../scripts/ci-published-supported-linux", __dir__),
      org_slug,
      box_version
    ]

    stdout, stderr, status = Open3.capture3(*command)

    expect(status.success?).to be(true), <<~MESSAGE
      published acceptance workflow failed
      stdout:
      #{stdout}

      stderr:
      #{stderr}
    MESSAGE
    expect(stdout).to include("verified vagrant plugin install provides vagrant-provider-avf")
    expect(stdout).to include("verified vagrant box add fetches #{org_slug}/ubuntu-24.04-arm64 #{box_version}")
    expect(stdout).to include("verified vagrant box add fetches #{org_slug}/almalinux-9-arm64 #{box_version}")
    expect(stdout).to include("verified vagrant box add fetches #{org_slug}/rocky-9-arm64 #{box_version}")
    expect(stdout).to include("verified vagrant destroy returns the machine to not_created")
  end
end
