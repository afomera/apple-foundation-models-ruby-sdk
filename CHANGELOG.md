# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial Ruby bindings for Apple's on-device Foundation Models framework, built on
  the same Swift/C bridge as Apple's Python SDK and loaded via the `ffi` gem.
- `SystemLanguageModel` with availability checks.
- `LanguageModelSession` with blocking `respond` and cumulative `stream_response`
  (block or `Enumerator`).
- `GenerationOptions` and `SamplingMode` (greedy / random with top-k, nucleus, seed).
- Guided generation: the `Generable` mixin DSL, `GenerationSchema`, `GenerationGuide`,
  `GeneratedContent`, and `respond(generating:/schema:/json_schema:)`, including nested
  generables.
- Tools the model can call back into during generation (`Tool` base class).
- Transcript export/import and `LanguageModelSession.from_transcript`.
- Multimodal prompts via image `Attachment`s.
- A Fiber-based async layer (`session.async.respond` / `stream_response`).
- Cancellation: `timeout:` on `respond`/`stream_response` (raising `TimeoutError`), and
  clean cancellation on early `break` from a streaming block.
