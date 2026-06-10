# frozen_string_literal: true

require "spec_helper"

RSpec.describe FoundationModels do
  it "has a version number" do
    expect(FoundationModels::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  it "loads the native dylib through its own loader" do
    expect(File.exist?(FoundationModels::Library::LIBRARY_PATH)).to be(true)
  end

  it "exposes FM as a short alias" do
    expect(FM).to equal(FoundationModels)
  end
end

RSpec.describe FoundationModels::SystemLanguageModel do
  it "can be created and reports availability without raising" do
    model = described_class.new
    available, reason = model.availability
    expect(available).to be(true).or be(false)
    expect(reason).to be_nil if available
  end

  it "releases its native pointer on GC without crashing" do
    10.times { described_class.new }
    expect { GC.start }.not_to raise_error
  end

  it "is available on this machine", :device do
    expect(described_class.new.available?).to be(true)
  end
end
