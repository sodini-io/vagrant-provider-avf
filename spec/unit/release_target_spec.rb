require "spec_helper"

RSpec.describe VagrantPlugins::AVF::ReleaseTarget do
  it "treats ubuntu as a supported release target" do
    target = described_class.new("myorg/ubuntu-24.04-arm64")

    expect(target.support_status).to eq(:supported)
    expect { target.validate_publishable! }.not_to raise_error
  end

  it "treats almalinux as a supported release target" do
    target = described_class.new("myorg/almalinux-9-arm64")

    expect(target.support_status).to eq(:supported)
    expect { target.validate_publishable! }.not_to raise_error
  end

  it "treats rocky as a supported release target" do
    target = described_class.new("myorg/rocky-9-arm64")

    expect(target.support_status).to eq(:supported)
    expect { target.validate_publishable! }.not_to raise_error
  end

  it "rejects unknown release targets" do
    target = described_class.new("myorg/oraclelinux-9-arm64")

    expect(target.support_status).to eq(:unknown)
    expect { target.validate_publishable! }
      .to raise_error(ArgumentError, /not a supported release target/)
  end
end
