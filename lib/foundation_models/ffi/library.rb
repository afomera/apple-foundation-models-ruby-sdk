# frozen_string_literal: true

require "ffi"

module FoundationModels
  # Low-level FFI binding to libFoundationModels.dylib (the vendored Swift/C bridge).
  #
  # This module is internal. It mirrors ext/foundation-models-c/.../include/FoundationModels.h
  # one-to-one. Higher-level Ruby classes wrap these calls with idiomatic APIs and
  # memory management (see ManagedObject).
  module Library
    extend ::FFI::Library

    # Locate the vendored dylib across dev and installed layouts.
    def self.candidate_paths
      name = "libFoundationModels.dylib"
      paths = []
      paths << File.join(__dir__, "..", "native", name) # lib/foundation_models/native (vendored)
      paths << File.join(RbConfig::CONFIG["sitearchdir"], name) if RbConfig::CONFIG["sitearchdir"]
      # Development fallback: the in-tree Swift build output.
      gem_root = File.expand_path("../../..", __dir__)
      paths << File.join(gem_root, "ext", "foundation-models-c", ".build", "out", "Products", "Release", name)
      paths << File.join(gem_root, "ext", "foundation-models-c", ".build", "release", name)
      paths.map { |p| File.expand_path(p) }.select { |p| File.exist?(p) }
    end

    found = candidate_paths.first
    unless found
      raise LoadError, <<~MSG
        Could not find libFoundationModels.dylib. Build the native bindings first:

          bundle exec rake build_native

        (requires macOS 26+ and a full Xcode 26+ installation).
      MSG
    end

    ffi_lib found
    LIBRARY_PATH = found

    # Tracks optional symbols that are declared in the C header but may not be
    # implemented in the linked dylib (e.g. SDK-gated functions). Populated at load.
    AVAILABLE_OPTIONAL = {} # rubocop:disable Style/MutableConstant

    # Attach a function that may be absent from the dylib. Records availability in
    # AVAILABLE_OPTIONAL instead of raising at load time (FFI resolves eagerly).
    def self.attach_optional(name, args, ret, **opts)
      attach_function(name, args, ret, **opts)
      AVAILABLE_OPTIONAL[name] = true
    rescue ::FFI::NotFoundError
      AVAILABLE_OPTIONAL[name] = false
    end

    # ----- Callback typedefs (match FoundationModels.h) -----

    # void (*)(int status, const char *content, size_t length, void *userInfo)
    callback :response_callback, %i[int pointer size_t pointer], :void
    # void (*)(int status, FMGeneratedContentRef content, void *userInfo)
    callback :structured_callback, %i[int pointer pointer], :void
    # void (*)(FMGeneratedContentRef, unsigned int)
    callback :tool_callback, %i[pointer uint], :void

    # ----- SystemLanguageModel -----
    attach_function :FMSystemLanguageModelGetDefault, [], :pointer
    attach_function :FMSystemLanguageModelCreate, %i[int int], :pointer
    attach_function :FMSystemLanguageModelIsAvailable, %i[pointer pointer], :bool

    # ----- LanguageModelSession -----
    attach_function :FMLanguageModelSessionCreateDefault, [], :pointer
    attach_function :FMLanguageModelSessionCreateFromSystemLanguageModel,
                    %i[pointer string pointer int], :pointer
    attach_function :FMLanguageModelSessionCreateFromTranscript,
                    %i[pointer pointer pointer int], :pointer
    attach_function :FMLanguageModelSessionIsResponding, [:pointer], :bool
    attach_function :FMLanguageModelSessionReset, [:pointer], :void
    attach_function :FMLanguageModelSessionRespond,
                    %i[pointer pointer string pointer response_callback], :pointer
    attach_function :FMLanguageModelSessionStreamResponse,
                    %i[pointer pointer string], :pointer
    attach_function :FMLanguageModelSessionResponseStreamIterate,
                    %i[pointer pointer response_callback], :void, blocking: true

    # ----- Composed prompts -----
    attach_function :FMComposedPromptInitialize, [], :pointer
    attach_function :FMComposedPromptAddText, %i[pointer string], :void
    attach_function :FMComposedPromptAddAttachment, %i[pointer string string pointer], :bool
    # Declared in the header but not implemented in all SDK builds; image input is
    # supported via FMComposedPromptAddAttachment.
    attach_optional :FMComposedPromptAddImage, %i[pointer string pointer], :bool
    attach_optional :FMComposedPromptAddIdentifiedImage, %i[pointer string string pointer], :bool

    # ----- Transcript -----
    attach_function :FMTranscriptCreateFromJSONString, %i[string pointer pointer], :pointer
    attach_function :FMLanguageModelSessionGetTranscriptJSONString, %i[pointer pointer pointer], :pointer

    # ----- GenerationSchema -----
    attach_function :FMGenerationSchemaCreate, %i[string string], :pointer
    attach_function :FMGenerationSchemaPropertyCreate, %i[string string string bool], :pointer
    attach_function :FMGenerationSchemaPropertyAddAnyOfGuide, %i[pointer pointer int bool], :void
    attach_function :FMGenerationSchemaPropertyAddCountGuide, %i[pointer int bool], :void
    attach_function :FMGenerationSchemaPropertyAddMaximumGuide, %i[pointer double bool], :void
    attach_function :FMGenerationSchemaPropertyAddMinimumGuide, %i[pointer double bool], :void
    attach_function :FMGenerationSchemaPropertyAddMinItemsGuide, %i[pointer int], :void
    attach_function :FMGenerationSchemaPropertyAddMaxItemsGuide, %i[pointer int], :void
    attach_function :FMGenerationSchemaPropertyAddRangeGuide, %i[pointer double double bool], :void
    attach_function :FMGenerationSchemaPropertyAddRegex, %i[pointer string bool], :void
    attach_function :FMGenerationSchemaAddProperty, %i[pointer pointer], :void
    attach_function :FMGenerationSchemaAddReferenceSchema, %i[pointer pointer], :void
    attach_function :FMGenerationSchemaGetJSONString, %i[pointer pointer pointer], :pointer

    # ----- GeneratedContent -----
    attach_function :FMGeneratedContentCreateFromJSON, %i[string pointer pointer], :pointer
    attach_function :FMGeneratedContentGetJSONString, [:pointer], :pointer
    attach_function :FMGeneratedContentGetPropertyValue, %i[pointer string pointer pointer], :pointer
    attach_function :FMGeneratedContentIsComplete, [:pointer], :bool

    # ----- Structured (guided) generation -----
    attach_function :FMLanguageModelSessionRespondWithSchema,
                    %i[pointer pointer pointer string pointer structured_callback], :pointer
    attach_function :FMLanguageModelSessionRespondWithSchemaFromJSON,
                    %i[pointer pointer string string pointer structured_callback], :pointer

    # ----- Tools -----
    attach_function :FMBridgedToolCreate,
                    %i[string string pointer tool_callback pointer pointer], :pointer
    attach_function :FMBridgedToolFinishCall, %i[pointer uint string], :void

    # ----- Memory management -----
    attach_function :FMTaskCancel, [:pointer], :void
    attach_function :FMRetain, [:pointer], :void
    attach_function :FMRelease, [:pointer], :void
    attach_function :FMFreeString, [:pointer], :void

    # Read a malloc'd (strdup'd) C string returned by the bridge and free it with
    # FMFreeString. Returns nil for a null pointer.
    def self.consume_string(ptr)
      return nil if ptr.nil? || ptr.null?

      str = ptr.read_string.force_encoding(Encoding::UTF_8)
      FMFreeString(ptr)
      str
    end
  end
end
