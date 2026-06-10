# frozen_string_literal: true

require "spec_helper"
require "async"

RSpec.describe FoundationModels::AsyncSession do
  it "is returned by LanguageModelSession#async" do
    expect(FoundationModels::LanguageModelSession.new.async).to be_a(described_class)
  end

  describe "under a reactor", :device do
    it "resolves a respond without blocking the reactor" do
      Async do
        session = FoundationModels::LanguageModelSession.new(instructions: "Be concise.")
        answer = session.async.respond("Capital of France?")
        expect(answer).to match(/paris/i)
      end
    end

    it "runs two requests concurrently across sessions" do
      Async do
        s1 = FoundationModels::LanguageModelSession.new(instructions: "Be concise.")
        s2 = FoundationModels::LanguageModelSession.new(instructions: "Be concise.")
        results = {}
        t1 = Async { results[:a] = s1.async.respond("Capital of France?") }
        t2 = Async { results[:b] = s2.async.respond("Capital of Japan?") }
        t1.wait
        t2.wait
        expect(results[:a]).to match(/paris/i)
        expect(results[:b]).to match(/tokyo/i)
      end
    end

    it "streams snapshots asynchronously" do
      Async do
        session = FoundationModels::LanguageModelSession.new(instructions: "Be concise.")
        snapshots = []
        session.async.stream_response("List two colors.") { |s| snapshots << s }
        expect(snapshots).not_to be_empty
      end
    end
  end
end
