# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Cancellation", :device do
  let(:long_prompt) { "Write a very long, detailed 2000-word essay about the history of computing." }

  describe "#respond timeout" do
    it "raises TimeoutError when the request exceeds the timeout" do
      session = FoundationModels::LanguageModelSession.new
      expect { session.respond(long_prompt, timeout: 0.2) }
        .to raise_error(FoundationModels::TimeoutError)
    end

    it "leaves the session idle and reusable after a timeout" do
      session = FoundationModels::LanguageModelSession.new
      begin
        session.respond(long_prompt, timeout: 0.2)
      rescue StandardError
        FoundationModels::TimeoutError
      end
      expect(session.responding?).to be(false)
      expect(session.respond("Say hello in one word.")).to be_a(String)
    end

    it "is a kind of CancelledError" do
      expect(FoundationModels::TimeoutError.ancestors).to include(FoundationModels::CancelledError)
    end
  end

  describe "#stream_response" do
    it "allows breaking early and remains reusable" do
      session = FoundationModels::LanguageModelSession.new
      count = 0
      session.stream_response("Count slowly from 1 to 50.") do |_snapshot|
        count += 1
        break if count >= 2
      end
      expect(count).to be >= 1
      expect(session.respond("Say bye in one word.")).to be_a(String)
    end

    it "raises TimeoutError when no snapshot arrives in time" do
      session = FoundationModels::LanguageModelSession.new
      expect { session.stream_response("Write a long essay.", timeout: 0.01) { |snap| snap } }
        .to raise_error(FoundationModels::TimeoutError)
    end
  end
end
