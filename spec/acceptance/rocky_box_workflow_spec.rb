require "open3"
require "spec_helper"

RSpec.describe "rocky box workflow", :real_acceptance do
  it "verifies the supported vagrant command flow end to end" do
    command = [File.expand_path("../../scripts/run-acceptance-rocky", __dir__)]
    stdout, stderr, status = Open3.capture3(*command)

    expect(status.success?).to be(true), <<~MESSAGE
      acceptance workflow failed
      stdout:
      #{stdout}

      stderr:
      #{stderr}
    MESSAGE
    expect(stdout).to include("verified vagrant validate accepts the generated Vagrantfile")
    expect(stdout).to include("verified vagrant up reaches running")
    expect(stdout).to include("verified vagrant ssh reaches the guest")
    expect(stdout).to include("verified vagrant destroy returns the machine to not_created")
  end
end
