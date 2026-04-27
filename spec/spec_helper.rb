$LOAD_PATH.unshift(File.expand_path("support", __dir__))
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "rspec"
require "vagrant-provider-avf"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.filter_run_excluding real_acceptance: true unless ENV["AVF_REAL_ACCEPTANCE"] == "1"
  config.filter_run_excluding published_acceptance: true unless ENV["AVF_REAL_PUBLISHED_ACCEPTANCE"] == "1"

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
