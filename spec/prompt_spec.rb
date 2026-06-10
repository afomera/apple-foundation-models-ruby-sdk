# frozen_string_literal: true

require "spec_helper"

RSpec.describe FoundationModels::Prompt do
  it "composes a text prompt into a native pointer" do
    ptr = described_class.compose("hello")
    expect(ptr).to be_a(FFI::Pointer)
    expect(ptr.null?).to be(false)
    FoundationModels::Library.FMRelease(ptr)
  end

  it "composes a mixed array of text and attachments" do
    image = File.expand_path("fixtures/sample.jpeg", __dir__)
    ptr = described_class.compose(["describe:", FoundationModels::Attachment.new(image)])
    expect(ptr.null?).to be(false)
    FoundationModels::Library.FMRelease(ptr)
  end

  it "raises on an unsupported component" do
    expect { described_class.compose([123]) }.to raise_error(FoundationModels::PromptError)
  end

  describe "image prompts", :device do
    it "answers a question about an attached image" do
      image = File.expand_path("fixtures/sample.jpeg", __dir__)
      session = FoundationModels::LanguageModelSession.new(instructions: "Describe images briefly.")
      answer = session.respond(["What is in this image? One sentence.", FoundationModels::Attachment.new(image)])
      expect(answer).to be_a(String)
      expect(answer).not_to be_empty
    end
  end
end
