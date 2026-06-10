# frozen_string_literal: true

require "foundation_models"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # Tag examples with `:device` when they require Apple Intelligence to be available.
  # They are skipped automatically when the model is unavailable.
  config.before(:context, :device) do
    model = FoundationModels::SystemLanguageModel.new
    skip("Foundation Models not available on this machine") unless model.available?
  end
end
