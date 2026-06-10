# frozen_string_literal: true

# Basic blocking inference.
#   ruby -Ilib examples/simple_inference.rb

require "foundation_models"

model = FoundationModels::SystemLanguageModel.new

unless model.available?
  _available, reason = model.availability
  abort "Foundation Models not available: #{reason}"
end

session = FoundationModels::LanguageModelSession.new(
  instructions: "You are a helpful, concise assistant.",
)

puts session.respond("What is the Swift programming language, in one sentence?")
