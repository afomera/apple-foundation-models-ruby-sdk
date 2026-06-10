# frozen_string_literal: true

# Concurrent requests using the Fiber-based async layer.
#   ruby -Ilib examples/async_concurrent.rb
#
# Requires the `async` gem: gem install async

require "foundation_models"
require "async"

Async do
  s1 = FoundationModels::LanguageModelSession.new(instructions: "Be concise.")
  s2 = FoundationModels::LanguageModelSession.new(instructions: "Be concise.")

  # These two requests run concurrently; the reactor multiplexes while each waits
  # on the model (the native call is offloaded to a thread per request).
  a = Async { s1.async.respond("What is the capital of France?") }
  b = Async { s2.async.respond("What is the capital of Japan?") }

  puts "France: #{a.wait}"
  puts "Japan:  #{b.wait}"
end
