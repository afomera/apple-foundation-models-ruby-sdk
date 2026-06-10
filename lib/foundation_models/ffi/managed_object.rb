# frozen_string_literal: true

module FoundationModels
  # Base class for Ruby objects that wrap a retained native pointer.
  #
  # The Swift bridge hands back pointers with a +1 reference count (passRetained).
  # We wrap them in an FFI::AutoPointer whose finalizer calls FMRelease exactly once
  # when the Ruby object is garbage collected — mirroring Swift ARC semantics.
  class ManagedObject
    # @return [FFI::AutoPointer] the managed native pointer
    attr_reader :ptr

    def initialize(ptr)
      raise FoundationModels::Error, "Failed to create native Foundation Models object" if ptr.nil? || ptr.null?

      @ptr = ::FFI::AutoPointer.new(ptr, Library.method(:FMRelease))
    end
  end
end
