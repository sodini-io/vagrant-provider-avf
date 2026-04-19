require "open3"
require "spec_helper"

RSpec.describe "almalinux box workflow", :real_acceptance do
  it "boots, reconnects after restart, and destroys through vagrant" do
    command = [File.expand_path("../../scripts/run-acceptance-almalinux", __dir__)]
    stdout, stderr, status = Open3.capture3(*command)

    expect(status.success?).to be(true), <<~MESSAGE
      acceptance workflow failed
      stdout:
      #{stdout}

      stderr:
      #{stderr}
    MESSAGE
  end
end
