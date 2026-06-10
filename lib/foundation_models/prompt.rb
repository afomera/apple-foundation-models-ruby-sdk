# frozen_string_literal: true

module FoundationModels
  # Raised when a prompt cannot be composed.
  class PromptError < Error; end

  # Raised when an image/attachment cannot be added to a prompt.
  class ImagePromptError < PromptError; end

  # An image attachment for a multimodal prompt.
  #
  # @example
  #   prompt = ["Describe this:", FoundationModels::Attachment.new("/path/to/cat.jpg")]
  #   session.respond(prompt)
  class Attachment
    attr_reader :path, :label

    # @param path [String] filesystem path to the image
    # @param label [String, nil] optional label describing the attachment
    def initialize(path, label: nil)
      @path = path
      @label = label
    end

    # Add this attachment to a native composed-prompt pointer.
    # @api private
    def add_to(composed_ptr)
      error = ::FFI::MemoryPointer.new(:int)
      ok = Library.FMComposedPromptAddAttachment(composed_ptr, path.to_s, label, error)
      return if ok

      reason = error.read_int
      raise ImagePromptError, "Failed to add attachment '#{path}' (error code #{reason})"
    end
  end

  # Backwards/parity alias for image-only attachments.
  ImageAttachment = Attachment

  # Builds native composed prompts from Ruby prompt values.
  module Prompt
    module_function

    # Accepts a String, an {Attachment}, or an Array mixing Strings and Attachments.
    # Returns a native composed-prompt pointer that the caller MUST release with
    # FMRelease once the request has been dispatched.
    #
    # @return [FFI::Pointer]
    def compose(prompt)
      composed = Library.FMComposedPromptInitialize
      Array(prompt).each { |component| add_component(composed, component) }
      composed
    end

    # @api private
    def add_component(composed, component)
      case component
      when String
        Library.FMComposedPromptAddText(composed, component)
      when Attachment
        component.add_to(composed)
      else
        raise PromptError,
              "Unsupported prompt component #{component.class}; expected String or Attachment"
      end
    end
  end
end
