# frozen_string_literal: true

module FoundationModels
  # Base class for all Foundation Models errors.
  class Error < StandardError; end

  # Base class for generation-specific errors.
  class GenerationError < Error; end

  # Raised when a request is cancelled (e.g. via a timeout or thread interruption).
  class CancelledError < Error; end

  # Raised when a request exceeds its `timeout:`.
  class TimeoutError < CancelledError; end

  # Raised when a generation schema is invalid.
  class InvalidGenerationSchemaError < Error; end

  # Raised when the model's context window size is exceeded.
  class ExceededContextWindowSizeError < GenerationError; end

  # Raised when required model assets are unavailable.
  class AssetsUnavailableError < GenerationError; end

  # Raised when a safety guardrail is triggered.
  class GuardrailViolationError < GenerationError; end

  # Raised when an unsupported generation guide is used.
  class UnsupportedGuideError < GenerationError; end

  # Raised when an unsupported language or locale is requested.
  class UnsupportedLanguageOrLocaleError < GenerationError; end

  # Raised when the model's response cannot be decoded.
  class DecodingFailureError < GenerationError; end

  # Raised when requests are rate limited.
  class RateLimitedError < GenerationError; end

  # Raised when too many concurrent requests are made to a session.
  class ConcurrentRequestsError < GenerationError; end

  # Raised when the model refuses to generate content.
  class RefusalError < GenerationError
    attr_reader :explanation_entries

    def initialize(message, explanation_entries: nil)
      super(message)
      @explanation_entries = explanation_entries || []
    end
  end

  # Raised when a tool invocation fails.
  class ToolCallError < Error
    attr_reader :tool_name, :underlying_error

    def initialize(tool_name, underlying_error)
      super("Tool '#{tool_name}' failed: #{underlying_error}")
      @tool_name = tool_name
      @underlying_error = underlying_error
    end
  end

  # Status codes returned by the native bridge, mapped to error classes.
  module GenerationErrorCode
    SUCCESS = 0
    EXCEEDED_CONTEXT_WINDOW_SIZE = 1
    ASSETS_UNAVAILABLE = 2
    GUARDRAIL_VIOLATION = 3
    UNSUPPORTED_GUIDE = 4
    UNSUPPORTED_LANGUAGE_OR_LOCALE = 5
    DECODING_FAILURE = 6
    RATE_LIMITED = 7
    CONCURRENT_REQUESTS = 8
    REFUSAL = 9
    INVALID_SCHEMA = 10
    UNKNOWN_ERROR = 255
  end

  # Maps a native status code to the appropriate error instance.
  #
  # @param status_code [Integer]
  # @param debug_description [String, nil]
  # @return [FoundationModels::GenerationError]
  def self.error_for_status(status_code, debug_description: nil)
    mapping = {
      GenerationErrorCode::EXCEEDED_CONTEXT_WINDOW_SIZE => [ExceededContextWindowSizeError,
                                                            "Context window size exceeded",],
      GenerationErrorCode::ASSETS_UNAVAILABLE => [AssetsUnavailableError, "Required assets are unavailable"],
      GenerationErrorCode::GUARDRAIL_VIOLATION => [GuardrailViolationError, "Guardrail violation occurred"],
      GenerationErrorCode::UNSUPPORTED_GUIDE => [UnsupportedGuideError, "Unsupported guide used"],
      GenerationErrorCode::UNSUPPORTED_LANGUAGE_OR_LOCALE => [UnsupportedLanguageOrLocaleError,
                                                              "Unsupported language or locale",],
      GenerationErrorCode::DECODING_FAILURE => [DecodingFailureError, "Failed to decode response"],
      GenerationErrorCode::RATE_LIMITED => [RateLimitedError, "Request was rate limited"],
      GenerationErrorCode::CONCURRENT_REQUESTS => [ConcurrentRequestsError, "Too many concurrent requests"],
      GenerationErrorCode::REFUSAL => [RefusalError, "Model refused to generate content"],
      GenerationErrorCode::INVALID_SCHEMA => [InvalidGenerationSchemaError, "Invalid generation schema provided"],
    }

    klass, message = mapping[status_code]
    if klass
      full = debug_description ? "#{message}: #{debug_description}" : message
      klass.new(full)
    else
      GenerationError.new("Generation error (status: #{status_code}): #{debug_description}")
    end
  end
end
