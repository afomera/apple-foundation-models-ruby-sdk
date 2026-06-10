# frozen_string_literal: true

module FoundationModels
  # Use cases that optimize the system model's behavior for specific tasks.
  module SystemLanguageModelUseCase
    GENERAL = 0
    CONTENT_TAGGING = 1
  end

  # Guardrail (content-filtering) settings for the system model.
  module SystemLanguageModelGuardrails
    DEFAULT = 0
    PERMISSIVE_CONTENT_TRANSFORMATIONS = 1
  end

  # Reasons the system model may be unavailable.
  module SystemLanguageModelUnavailableReason
    APPLE_INTELLIGENCE_NOT_ENABLED = 0
    DEVICE_NOT_ELIGIBLE = 1
    MODEL_NOT_READY = 2
    UNKNOWN = 0xFF

    NAMES = {
      APPLE_INTELLIGENCE_NOT_ENABLED => :apple_intelligence_not_enabled,
      DEVICE_NOT_ELIGIBLE => :device_not_eligible,
      MODEL_NOT_READY => :model_not_ready,
      UNKNOWN => :unknown,
    }.freeze

    def self.name_for(code)
      NAMES.fetch(code, :unknown)
    end
  end

  # The on-device foundation model at the core of Apple Intelligence.
  #
  # @example
  #   model = FoundationModels::SystemLanguageModel.new
  #   if model.available?
  #     # ready for inference
  #   end
  class SystemLanguageModel < ManagedObject
    # @param use_case [Integer] one of SystemLanguageModelUseCase
    # @param guardrails [Integer] one of SystemLanguageModelGuardrails
    def initialize(use_case: SystemLanguageModelUseCase::GENERAL,
                   guardrails: SystemLanguageModelGuardrails::DEFAULT,
                   ptr: nil)
      super(ptr || Library.FMSystemLanguageModelCreate(use_case, guardrails))
    end

    # @return [Boolean] whether the model is ready for use on this device
    def available?
      reason = ::FFI::MemoryPointer.new(:int)
      Library.FMSystemLanguageModelIsAvailable(@ptr, reason)
    end

    # @return [Array(Boolean, Symbol|nil)] [available, reason_symbol_or_nil]
    def availability
      reason = ::FFI::MemoryPointer.new(:int)
      ok = Library.FMSystemLanguageModelIsAvailable(@ptr, reason)
      return [true, nil] if ok

      [false, SystemLanguageModelUnavailableReason.name_for(reason.read_int)]
    end
  end
end
