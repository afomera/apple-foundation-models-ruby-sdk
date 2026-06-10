# frozen_string_literal: true

require_relative "foundation_models/version"
require_relative "foundation_models/errors"
require_relative "foundation_models/ffi/library"
require_relative "foundation_models/ffi/managed_object"
require_relative "foundation_models/system_language_model"
require_relative "foundation_models/generation_options"
require_relative "foundation_models/prompt"
require_relative "foundation_models/transcript"
require_relative "foundation_models/type_conversion"
require_relative "foundation_models/generation_guide"
require_relative "foundation_models/generation_property"
require_relative "foundation_models/generation_schema"
require_relative "foundation_models/generated_content"
require_relative "foundation_models/generable"
require_relative "foundation_models/tool"
require_relative "foundation_models/language_model_session"
require_relative "foundation_models/async"

# Ruby bindings for Apple's on-device Foundation Models framework.
module FoundationModels
end

# Short alias.
FM = FoundationModels unless defined?(FM)
