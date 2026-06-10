# frozen_string_literal: true

require "json"

module FoundationModels
  # A snapshot of a session's conversation history (instructions, prompts, responses,
  # and tool interactions), importable/exportable as JSON.
  #
  # Obtain one via {LanguageModelSession#transcript}, or build one from saved JSON with
  # {from_json}/{from_h} to resume a conversation via {LanguageModelSession.from_transcript}.
  class Transcript < ManagedObject
    # Build a transcript from a JSON string previously exported by a session
    # (Ruby or a Swift app).
    def self.from_json(json_string)
      err_code = ::FFI::MemoryPointer.new(:int)
      err_desc = ::FFI::MemoryPointer.new(:pointer)
      ptr = Library.FMTranscriptCreateFromJSONString(json_string, err_code, err_desc)

      if ptr.nil? || ptr.null?
        raise FoundationModels.error_for_status(
          err_code.read_int,
          debug_description: Library.consume_string(err_desc.read_pointer),
        )
      end

      new(ptr)
    end

    # Build a transcript from a Hash.
    def self.from_h(hash)
      from_json(JSON.generate(hash))
    end

    # @return [Hash] the transcript as a JSON-compatible Hash
    def to_h
      err_code = ::FFI::MemoryPointer.new(:int)
      err_desc = ::FFI::MemoryPointer.new(:pointer)
      json_ptr = Library.FMLanguageModelSessionGetTranscriptJSONString(ptr, err_code, err_desc)

      if json_ptr.nil? || json_ptr.null?
        raise FoundationModels.error_for_status(
          err_code.read_int,
          debug_description: Library.consume_string(err_desc.read_pointer),
        )
      end

      JSON.parse(Library.consume_string(json_ptr))
    end

    # @return [String] the transcript as a JSON string
    def to_json(*_args)
      JSON.generate(to_h)
    end
  end
end
