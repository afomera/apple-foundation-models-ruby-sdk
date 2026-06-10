# frozen_string_literal: true

module FoundationModels
  # Sentinel type for boolean schema properties (Ruby has no Boolean class).
  # Use it in property declarations: `property :active, FoundationModels::Boolean`.
  Boolean = Object.new
  def Boolean.inspect = "FoundationModels::Boolean"
  def Boolean.to_s = "FoundationModels::Boolean"

  # Converts Ruby property types to the schema type strings the native bridge expects.
  #
  # Mapping (parity with the Python SDK):
  #   String  -> "string"      Integer -> "integer"
  #   Float   -> "number"      Boolean -> "boolean"
  #   [T]     -> "array<T>"    a Generable class -> its schema name
  module TypeConversion
    module_function

    def type_name(type)
      case type
      when Array
        unless type.length == 1
          raise InvalidGenerationSchemaError,
                "Array property types must specify exactly one element type, e.g. [String]"
        end
        "array<#{type_name(type.first)}>"
      when :string then "string"
      when :integer then "integer"
      when :number, :float then "number"
      when :boolean then "boolean"
      else
        if type == String then "string"
        elsif type == Integer then "integer"
        elsif type == Float then "number"
        elsif type.equal?(Boolean) then "boolean"
        elsif generable_class?(type) then type.fm_schema_name
        else
          raise InvalidGenerationSchemaError, "Unsupported property type: #{type.inspect}"
        end
      end
    end

    # @return [Boolean] whether `type` is a class that includes {Generable}
    def generable_class?(type)
      type.is_a?(Class) && type.include?(FoundationModels::Generable)
    end
  end
end
