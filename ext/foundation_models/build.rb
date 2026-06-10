# frozen_string_literal: true

require "fileutils"
require "rbconfig"

# Builds the vendored `foundation-models-c` Swift package and vendors the resulting
# libFoundationModels.dylib into lib/foundation_models/native/.
#
# Shared by the Rakefile (development) and ext/foundation_models/extconf.rb (gem install).
# Ported from the reference Python SDK's build_backend.py toolchain checks.
module FoundationModelsBuild
  module_function

  DYLIB_NAME = "libFoundationModels.dylib"

  # Repo/gem root (two levels up from this file: ext/foundation_models/build.rb).
  def gem_root
    File.expand_path("../..", __dir__)
  end

  def swift_package_dir
    File.join(gem_root, "ext", "foundation-models-c")
  end

  def native_dir
    File.join(gem_root, "lib", "foundation_models", "native")
  end

  class ToolingError < StandardError; end

  def run!(*cmd, chdir: nil)
    opts = {}
    opts[:chdir] = chdir if chdir
    out = IO.popen(cmd, err: %i[child out], **opts, &:read)
    [out, $?.success?]
  end

  def capture(*cmd)
    out, ok = run!(*cmd)
    ok ? out.strip : nil
  end

  def check_macos!
    raise ToolingError, "This gem only supports macOS." unless RbConfig::CONFIG["host_os"] =~ /darwin/

    version = capture("sw_vers", "-productVersion") || ""
    major = version.split(".").first.to_i
    return if major >= 26

    raise ToolingError,
          "macOS #{version} found, but macOS 26.0+ is required to build the Foundation Models bindings."
  end

  def check_swift!
    return if capture("which", "swift")

    raise ToolingError, "No `swift` executable found in PATH. Is the Swift toolchain installed?"
  end

  def check_full_xcode!
    developer_dir = capture("xcode-select", "-p") || ""
    if developer_dir.include?("CommandLineTools")
      raise ToolingError, <<~MSG
        The active developer directory is set to Command Line Tools (#{developer_dir}),
        but a full Xcode installation is required (Swift Package Manager does not work under
        Command Line Tools alone). Install Xcode 26+, then run:

          sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

        and open Xcode once to accept the license and install the SDKs.
      MSG
    end

    version_line = capture("xcodebuild", "-version")
    raise ToolingError, "Could not run `xcodebuild -version`. Is Xcode installed and selected?" unless version_line

    if (m = version_line.match(/Xcode\s+(\d+)\.(\d+)/))
      major = m[1].to_i
      raise ToolingError, "Xcode #{m[1]}.#{m[2]} found, but Xcode 26.0+ is required." if major < 26
    end
  end

  # The `Attachment` (image) API only exists in the macOS 27+ SDK.
  def sdk_major
    version = capture("xcrun", "--sdk", "macosx", "--show-sdk-version")
    version&.split(".")&.first&.to_i
  end

  def build!(configuration: "release", quiet: false)
    check_macos!
    check_swift!
    check_full_xcode!

    extra = []
    if (major = sdk_major) && major >= 27
      extra += ["-Xswiftc", "-DFM_HAS_MACOS_27_SDK"]
    end

    puts "Building Foundation Models Swift bindings (#{configuration})..." unless quiet
    out, ok = run!("swift", "build", "-c", configuration, *extra, chdir: swift_package_dir)
    raise ToolingError, "Failed to build the Swift bindings:\n#{out}" unless ok

    bin_path = capture_in(swift_package_dir, "swift", "build", "-c", configuration, "--show-bin-path")
    raise ToolingError, "Could not determine Swift build output path." unless bin_path

    built = File.join(bin_path, DYLIB_NAME)
    raise ToolingError, "Expected dylib not found at #{built}" unless File.exist?(built)

    FileUtils.mkdir_p(native_dir)
    dest = File.join(native_dir, DYLIB_NAME)
    FileUtils.cp(built, dest)

    # Make the dylib's install name self-relative so it resolves wherever it is vendored.
    system("install_name_tool", "-id", "@rpath/#{DYLIB_NAME}", dest,
           out: File::NULL, err: File::NULL,)

    puts "Vendored #{DYLIB_NAME} -> #{dest}" unless quiet
    dest
  end

  def capture_in(dir, *cmd)
    out, ok = run!(*cmd, chdir: dir)
    ok ? out.strip : nil
  end
end
