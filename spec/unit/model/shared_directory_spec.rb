require "spec_helper"

RSpec.describe VagrantPlugins::AVF::Model::SharedDirectory do
  it "builds a stable named directory payload for the AVF runner" do
    directory = described_class.new(
      id: "project-root",
      host_path: "/tmp/project",
      guest_path: "/vagrant"
    )

    expect(directory.name).to eq(described_class.name_for("project-root"))
    expect(directory.to_h).to eq(
      "hostPath" => "/tmp/project",
      "name" => described_class.name_for("project-root"),
      "readOnly" => false
    )
  end
end
