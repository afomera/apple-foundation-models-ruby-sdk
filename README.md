# Apple Foundation Models — Ruby SDK

Ruby bindings for Apple's [Foundation Models framework](https://developer.apple.com/documentation/foundationmodels),
providing access to the on-device foundation model at the core of Apple Intelligence on macOS.

This is a Ruby port of Apple's [`python-apple-fm-sdk`](https://github.com/apple/python-apple-fm-sdk).
It binds — via the [`ffi`](https://github.com/ffi/ffi) gem — to the same Swift/C bridge
(`libFoundationModels.dylib`) that the Python SDK uses.

Everything runs **on device**. No data leaves the machine, and no API key is required.

## Features

- On-device text generation (blocking) and real-time **streaming**
- **Guided generation** into typed Ruby objects via a small class DSL
- **Tools** the model can call back into during generation
- **Transcripts**: export a conversation and resume it later
- **Multimodal** prompts (image attachments)
- **Both** a simple blocking API and an optional **Fiber-based async** layer

## Requirements

- macOS 26.0+
- A full **Xcode 26.0+** installation (Command Line Tools alone are **not** sufficient —
  Swift Package Manager requires full Xcode). Point `xcode-select` at it:
  `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
- Apple Intelligence enabled on a [compatible Mac](https://support.apple.com/en-us/121115)
- Ruby 3.1+

## Installation

The gem builds a small Swift package at install time (hence the Xcode requirement).

```ruby
# Gemfile
gem "foundation-models"
```

For local development:

```bash
bundle install
bundle exec rake build_native   # builds the Swift bindings, vendors the dylib
bundle exec rspec               # device tests auto-skip when the model is unavailable
```

## Usage

The top-level module is `FoundationModels`. It is also available as the shorthand
alias `FM`, so `FoundationModels::LanguageModelSession` and `FM::LanguageModelSession`
are interchangeable. The examples below use the full name.

```ruby
require "foundation_models"

model = FoundationModels::SystemLanguageModel.new
abort "unavailable" unless model.available?
```

### Text generation

```ruby
session = FoundationModels::LanguageModelSession.new(instructions: "You are concise.")
puts session.respond("What is the capital of France?")   # => "Paris."
```

### Streaming

Snapshots are cumulative — each yields the full text so far.

```ruby
session.stream_response("Tell me a short story.") { |snapshot| print snapshot }
# or, without a block, get an Enumerator:
session.stream_response("...").each { |snapshot| ... }
```

### Generation options

```ruby
opts = FoundationModels::GenerationOptions.new(
  temperature: 0.7,
  sampling: FoundationModels::SamplingMode.random(top: 50, seed: 42),  # or .greedy
  maximum_response_tokens: 500,
)
session.respond("Write a haiku.", options: opts)
```

### Guided (structured) generation

```ruby
class Cat
  include FoundationModels::Generable
  generable description: "An adorable rescue cat"

  property :name, String
  property :age,  Integer, description: "Age in years", range: 0..20
  property :temperament, String, any_of: %w[playful shy affectionate]
  property :favorite_toys, [String], min_items: 1
end

cat = session.respond("Generate a rescue cat.", generating: Cat)
cat.name           # => "Mochi"
cat.favorite_toys  # => ["feather wand", "laser pointer"]
```

Property constraints: `description:`, `optional:`, `any_of:`, `constant:`, `count:`,
`min_items:`, `max_items:`, `minimum:`, `maximum:`, `range:` (a Ruby Range), `regex:`,
and `element:` (a `FoundationModels::GenerationGuide` applied to array elements).

Types: `String`, `Integer`, `Float`, `FoundationModels::Boolean`, `[T]` for arrays, and
other `Generable` classes for nesting.

You can also pass an explicit `schema:` (a `FoundationModels::GenerationSchema`) or a raw
`json_schema:` (in Foundation Models' schema dialect) — both return a
`FoundationModels::GeneratedContent`:

```ruby
content = session.respond("Generate a cat.", schema: Cat.generation_schema)
content.value(String, :name)
content.to_h
```

### Tools

```ruby
class WeatherArgs
  include FoundationModels::Generable
  property :city, String, description: "The city to look up"
end

class WeatherTool < FoundationModels::Tool
  tool_name "get_weather"
  description "Get the current weather for a city."
  arguments WeatherArgs

  def call(args)
    "It is 72°F and sunny in #{args.value(String, :city)}."
  end
end

session = FoundationModels::LanguageModelSession.new(tools: [WeatherTool.new])
session.respond("What's the weather in Cupertino?")  # model calls the tool, then answers
```

### Transcripts

```ruby
json = session.transcript_json                              # export
restored = FoundationModels::Transcript.from_json(json)
resumed  = FoundationModels::LanguageModelSession.from_transcript(restored)
resumed.respond("Continue where we left off.")
```

### Multimodal (image) prompts

```ruby
prompt = ["What is in this image?", FoundationModels::Attachment.new("/path/to/image.jpg")]
session.respond(prompt)
```

### Async (Fiber-based) layer

`session.async` offloads native work to a thread and cooperates with the
[`async`](https://github.com/socketry/async) reactor, so concurrent requests
multiplex instead of blocking:

```ruby
require "async"

Async do
  s1 = FoundationModels::LanguageModelSession.new
  s2 = FoundationModels::LanguageModelSession.new
  a = Async { s1.async.respond("Capital of France?") }
  b = Async { s2.async.respond("Capital of Japan?") }
  [a.wait, b.wait]
end
```

(Outside a reactor, `session.async.respond` simply behaves like the blocking call.)

### Cancellation & timeouts

Pass `timeout:` (seconds) to `respond` or `stream_response`. On expiry the native
request is cancelled, the session is reset, and `FoundationModels::TimeoutError` (a
`CancelledError`) is raised — the session remains usable afterward:

```ruby
session.respond("Write a long essay.", timeout: 5)             # => raises TimeoutError after 5s
session.stream_response("...", timeout: 2) { |snap| ... }      # per-snapshot timeout
```

Breaking out of a streaming block early also cleanly cancels the underlying request:

```ruby
session.stream_response("Count to 100.") do |snapshot|
  print snapshot
  break if snapshot.length > 100   # cancels the rest; session stays usable
end
```

## Errors

All errors inherit from `FoundationModels::Error`. Generation failures map to specific
subclasses (`GuardrailViolationError`, `ExceededContextWindowSizeError`, `RefusalError`,
`RateLimitedError`, `ConcurrentRequestsError`, …). Cancellations raise `CancelledError`
(and its subclass `TimeoutError`).

## Examples

See [`examples/`](examples/). Run them with `ruby -Ilib examples/<name>.rb`.

## Architecture

```
Ruby (ffi gem) → libFoundationModels.dylib → Swift → FoundationModels.framework
```

The vendored Swift package (`ext/foundation-models-c`) exposes a flat C ABI; the Ruby
layer attaches to it and wraps each call with idiomatic Ruby and ARC-style memory
management (`FFI::AutoPointer`).

## License

Apache-2.0.
