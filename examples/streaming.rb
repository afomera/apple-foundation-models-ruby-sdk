# frozen_string_literal: true

# Streaming text generation (cumulative snapshots).
#   ruby -Ilib examples/streaming.rb

require "foundation_models"

session = FoundationModels::LanguageModelSession.new(
  instructions: "You are a creative writer.",
)

previous_length = 0
session.stream_response("Write a two-sentence story about a robot learning to paint.") do |snapshot|
  # Each snapshot contains the full text so far; print only the newly added part.
  print snapshot[previous_length..]
  previous_length = snapshot.length
end
puts
