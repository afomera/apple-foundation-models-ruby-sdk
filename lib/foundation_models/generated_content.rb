# frozen_string_literal: true

require "json"

module FoundationModels
  # Structured content produced by guided generation.
  #
  # Wraps the native content object (parsing its JSON into a Hash) and exposes typed
  # accessors. Can also be constructed from a plain Hash for nested extraction.
  class GeneratedContent
    # @param ptr [FFI::Pointer, nil] a native FMGeneratedContentRef (ownership transferred)
    # @param hash [Hash, nil] a pre-parsed content hash (no native object)
    def initialize(ptr: nil, hash: nil)
      if ptr && !ptr.null?
        @ptr = ::FFI::AutoPointer.new(ptr, Library.method(:FMRelease))
        json = Library.consume_string(Library.FMGeneratedContentGetJSONString(@ptr))
        raise FoundationModels::Error, "Failed to read generated content" if json.nil?

        @hash = JSON.parse(json)
      else
        @ptr = nil
        @hash = hash || {}
      end
    end

    # @return [FFI::Pointer, nil] the native pointer, if backed by one
    attr_reader :ptr

    # Build from a JSON string (hash-backed, no native object).
    def self.from_json(json_string)
      new(hash: JSON.parse(json_string))
    end

    # Extract a value, optionally coerced to `type` and/or scoped to a property.
    #
    # @param type [Class, Symbol, Array, nil] desired type (see {TypeConversion})
    # @param for_property [String, Symbol, nil] property name, or nil for the whole content
    # @return [Object]
    def value(type = nil, for_property = nil)
      raw = for_property ? @hash[for_property.to_s] : @hash
      return raw if type.nil?

      coerce(raw, type)
    end

    # @return [Boolean] whether the underlying generation is complete (native only)
    def complete?
      return true if @ptr.nil?

      Library.FMGeneratedContentIsComplete(@ptr)
    end

    # @return [Hash] the parsed content
    def to_h = @hash

    # @return [String] the content as JSON
    def to_json(*_args) = JSON.generate(@hash)

    private

    def coerce(raw, type)
      return nil if raw.nil?

      case type
      when Array
        element_type = type.first
        Array(raw).map { |item| coerce(item, element_type) }
      when :string then raw.to_s
      when :integer then to_integer(raw)
      when :number, :float then to_float(raw)
      when :boolean then to_boolean(raw)
      else
        if type == String then raw.to_s
        elsif type == Integer then to_integer(raw)
        elsif type == Float then to_float(raw)
        elsif type.equal?(Boolean) then to_boolean(raw)
        elsif TypeConversion.generable_class?(type)
          type.from_generated_content(GeneratedContent.new(hash: raw))
        else
          raw
        end
      end
    end

    def to_integer(raw)
      Integer(raw)
    rescue ArgumentError, TypeError
      raw.to_i
    end

    def to_float(raw)
      Float(raw)
    rescue ArgumentError, TypeError
      raw.to_f
    end

    def to_boolean(raw)
      return raw if [true, false].include?(raw)

      %w[true 1 yes].include?(raw.to_s.strip.downcase)
    end
  end
end
