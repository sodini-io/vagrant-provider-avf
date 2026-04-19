require "spec_helper"

RSpec.describe VagrantPlugins::AVF::ProcessControl do
  it "spawns the helper detached from the calling terminal session" do
    allow(Process).to receive(:spawn).and_return(1234)

    process_id = described_class.new.spawn(%w[/tmp/avf-runner /tmp/request.json], out: "/tmp/out.log", err: "/tmp/err.log")

    expect(process_id).to eq(1234)
    expect(Process).to have_received(:spawn).with(
      "/tmp/avf-runner",
      "/tmp/request.json",
      in: File::NULL,
      out: "/tmp/out.log",
      err: "/tmp/err.log",
      pgroup: true
    )
  end
end
