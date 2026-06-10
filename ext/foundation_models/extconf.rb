# frozen_string_literal: true

# Gem-install build step. This is not a typical C extension: instead of compiling
# C with mkmf, it builds the vendored Swift package and vendors the resulting dylib
# into lib/foundation_models/native/. We then emit a no-op Makefile so RubyGems'
# `make` / `make install` invocation succeeds.

require_relative "build"

begin
  dylib = FoundationModelsBuild.build!
  # Also copy into the arch dir as a fallback lookup location for the loader.
  require "rbconfig"
  arch_dir = RbConfig::CONFIG["sitearchdir"]
  if arch_dir && File.directory?(File.dirname(arch_dir))
    require "fileutils"
    FileUtils.mkdir_p(arch_dir)
    FileUtils.cp(dylib, File.join(arch_dir, FoundationModelsBuild::DYLIB_NAME))
  end
rescue FoundationModelsBuild::ToolingError => e
  warn "\n[apple-foundation-models] Native build failed:\n#{e.message}\n"
  raise
end

File.write("Makefile", <<~MAKE)
  all:
  \t@true
  clean:
  \t@true
  install:
  \t@true
MAKE
