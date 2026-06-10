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

  # Tag examples with `:image` when they require image-attachment support, which is
  # only present when the bindings were built against the macOS 27+ SDK.
  config.before(:each, :image) do
    skip("Image attachments require the macOS 27+ SDK") unless SpecSupport.image_attachments?
  end
end

# Detects (once) whether image attachments are supported by the linked dylib.
module SpecSupport
  def self.image_attachments?
    return @image_attachments unless @image_attachments.nil?

    image = File.expand_path("fixtures/sample.jpeg", __dir__)
    ptr = FoundationModels::Prompt.compose(["probe", FoundationModels::Attachment.new(image)])
    FoundationModels::Library.FMRelease(ptr)
    @image_attachments = true
  rescue FoundationModels::ImagePromptError
    @image_attachments = false
  end
end
