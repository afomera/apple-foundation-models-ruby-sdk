# frozen_string_literal: true

require_relative "ext/foundation_models/build"

begin
  require "bundler/gem_tasks"
rescue LoadError
  # bundler not available; gem build/release tasks unavailable
end

begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  # rspec not installed; `rake spec` will be unavailable
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  # rubocop not installed; `rake rubocop` will be unavailable
end

desc "Build the Swift bindings and vendor the dylib into lib/foundation_models/native/"
task :build_native do
  FoundationModelsBuild.build!
end

desc "Remove built native artifacts"
task :clean_native do
  require "fileutils"
  FileUtils.rm_rf(FoundationModelsBuild.native_dir)
  FileUtils.rm_rf(File.join(FoundationModelsBuild.swift_package_dir, ".build"))
  puts "Cleaned native artifacts."
end

desc "Build native bindings, then run rubocop and specs"
task default: %i[build_native rubocop spec]
