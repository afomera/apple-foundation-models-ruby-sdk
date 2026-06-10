# frozen_string_literal: true

require "spec_helper"

RSpec.describe FoundationModels::LanguageModelSession do
  it "can be constructed without a device" do
    expect { described_class.new(instructions: "Be brief.") }.not_to raise_error
  end

  it "reports it is not responding when idle" do
    expect(described_class.new.responding?).to be(false)
  end

  describe "#respond", :device do
    it "returns a non-empty string answer" do
      session = described_class.new(instructions: "You are concise. Answer in one short sentence.")
      answer = session.respond("What is the capital of France?")
      expect(answer).to be_a(String)
      expect(answer).to match(/paris/i)
    end

    it "maintains context across turns" do
      session = described_class.new(instructions: "You are concise.")
      session.respond("My name is Andrea. Please remember it.")
      expect(session.respond("What is my name?")).to match(/andrea/i)
    end

    it "honors generation options" do
      session = described_class.new
      opts = FoundationModels::GenerationOptions.new(
        temperature: 0.0,
        sampling: FoundationModels::SamplingMode.greedy,
        maximum_response_tokens: 30,
      )
      expect(session.respond("Say hello.", options: opts)).to be_a(String)
    end

    it "is not responding after a completed request" do
      session = described_class.new
      session.respond("Hi")
      expect(session.responding?).to be(false)
    end
  end

  describe "#stream_response", :device do
    it "yields cumulative snapshots ending with the full text" do
      session = described_class.new(instructions: "You are concise.")
      snapshots = []
      session.stream_response("List three primary colors.") { |s| snapshots << s }
      expect(snapshots).not_to be_empty
      expect(snapshots.map(&:length)).to eq(snapshots.map(&:length).sort) # monotonic
      expect(snapshots.last).to be_a(String)
    end

    it "returns an Enumerator when no block is given" do
      session = described_class.new
      enum = session.stream_response("Count to three.")
      expect(enum).to be_a(Enumerator)
      expect(enum.to_a).not_to be_empty
    end
  end
end
