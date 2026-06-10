# frozen_string_literal: true

require_relative "lib/foundation_models/version"

Gem::Specification.new do |spec|
  spec.name        = "foundation-models"
  spec.version     = FoundationModels::VERSION
  spec.authors     = ["Andrea Fomera"]
  spec.email       = ["afomera@hey.com"]

  spec.summary     = "Ruby bindings for Apple's on-device Foundation Models framework"
  spec.description = <<~DESC
    Ruby bindings for Apple's Foundation Models framework, providing access to the
    on-device foundation model at the core of Apple Intelligence on macOS. Supports
    text generation, streaming, guided (structured) generation, tools, and transcripts.
  DESC
  spec.homepage = "https://github.com/afomera/apple-foundation-models-ruby-sdk"
  spec.license  = "Apache-2.0"

  spec.required_ruby_version = ">= 3.1"
  spec.platform              = Gem::Platform.new("arm64-darwin")

  spec.metadata["source_code_uri"]       = spec.homepage
  spec.metadata["changelog_uri"]         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"]       = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "ext/**/*",
    "README.md",
    "CHANGELOG.md",
    "LICENSE*",
    "NOTICE",
  ].reject { |f| f.include?("/.build/") || f.end_with?(".dylib") }

  spec.require_paths = ["lib"]

  # Builds the vendored Swift package (`swift build`) and vendors the dylib into
  # lib/foundation_models/native/ at install time. Requires macOS 26+ and Xcode 26+.
  spec.extensions = ["ext/foundation_models/extconf.rb"]

  spec.add_dependency "ffi", "~> 1.17"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.87"
  spec.add_development_dependency "rubocop-rspec", "~> 3.10"
end
