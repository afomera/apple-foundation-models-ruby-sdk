# frozen_string_literal: true

# Exporting a conversation transcript and resuming from it.
#   ruby -Ilib examples/transcript_processing.rb

require "foundation_models"
require "json"

session = FoundationModels::LanguageModelSession.new(instructions: "You are concise.")
session.respond("My favorite number is 7. Please remember it.")

# Export the conversation as JSON (e.g. to persist it).
json = session.transcript_json
puts "Exported transcript (#{json.bytesize} bytes)."

# ... later, in a fresh process, resume from the saved JSON:
restored = FoundationModels::Transcript.from_json(json)
resumed = FoundationModels::LanguageModelSession.from_transcript(restored)

puts resumed.respond("What is my favorite number?")
