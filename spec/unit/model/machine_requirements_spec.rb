require "spec_helper"

RSpec.describe VagrantPlugins::AVF::Model::MachineRequirements do
  it "fills in provider defaults when sizes are omitted" do
    requirements = described_class.new(
      cpus: nil,
      memory_mb: nil,
      disk_gb: nil,
      headless: true
    )

    expect(requirements.cpus).to eq(1)
    expect(requirements.memory_mb).to eq(1024)
    expect(requirements.disk_gb).to eq(16)
    expect(requirements.errors).to eq([])
  end

  it "coerces integer strings" do
    requirements = described_class.new(
      cpus: "2",
      memory_mb: "2048",
      disk_gb: "32",
      headless: false
    )

    expect(requirements.cpus).to eq(2)
    expect(requirements.memory_mb).to eq(2048)
    expect(requirements.disk_gb).to eq(32)
    expect(requirements.headless).to be(false)
    expect(requirements.errors).to eq([])
  end

  it "reports invalid values" do
    requirements = described_class.new(
      cpus: 0,
      memory_mb: "many",
      disk_gb: -1,
      headless: "yes"
    )

    expect(requirements.errors).to contain_exactly(
      "cpus must be greater than 0",
      "memory_mb must be an integer",
      "disk_gb must be greater than 0",
      "headless must be true or false"
    )
  end

  it "round-trips through a hash payload" do
    requirements = described_class.from_h(
      "cpus" => 2,
      "memory_mb" => 2048,
      "disk_gb" => 32,
      "headless" => false
    )

    expect(requirements.to_h).to eq(
      "cpus" => 2,
      "memory_mb" => 2048,
      "disk_gb" => 32,
      "headless" => false
    )
  end

  it "reports which fields changed" do
    previous = described_class.new(cpus: 2, memory_mb: 2048, disk_gb: 32, headless: true)
    current = described_class.new(cpus: 4, memory_mb: 2048, disk_gb: 64, headless: false)

    expect(previous.changed_fields(current)).to eq([:cpus, :disk_gb, :headless])
  end
end
