# frozen_string_literal: true

require "spec_helper"

RSpec.describe FoundationModels::Transcript do
  describe "round-tripping a hash without a device" do
    it "imports a transcript hash and re-exports it" do
      hash = FoundationModels::LanguageModelSession.new(instructions: "Be brief.")
      # An empty/instruction-only session still produces a valid transcript.
      json = hash.transcript_json
      restored = described_class.from_json(json)
      expect(restored.to_h).to be_a(Hash)
    end
  end

  describe "resuming a conversation", :device do
    it "preserves context across export/import" do
      session = FoundationModels::LanguageModelSession.new(instructions: "You are concise.")
      session.respond("My favorite number is 7. Remember it.")

      json = session.transcript_json
      restored = described_class.from_json(json)
      resumed = FoundationModels::LanguageModelSession.from_transcript(restored)

      expect(resumed.respond("What is my favorite number?")).to match(/7/)
    end

    it "exposes a transcript snapshot from a live session" do
      session = FoundationModels::LanguageModelSession.new
      session.respond("Hello")
      expect(session.transcript).to be_a(described_class)
      expect(session.transcript.to_h).to be_a(Hash)
    end
  end
end
