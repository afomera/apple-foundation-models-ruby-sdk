# frozen_string_literal: true

module FoundationModels
  # A constraint that guides how the model generates a property's value.
  #
  # Construct via the class helpers ({any_of}, {range}, {regex}, ...) or implicitly
  # through {Generable::ClassMethods#property} keyword constraints.
  class GenerationGuide
    # Keyword-constraint names accepted by {build} / `property`.
    CONSTRAINT_KEYS = %i[
      any_of constant count element max_items maximum min_items minimum range regex
    ].freeze

    attr_reader :type, :value

    def initialize(type, value)
      @type = type
      @value = value
    end

    class << self
      def any_of(values) = new(:any_of, Array(values))
      def constant(value) = new(:constant, value)
      def count(n) = new(:count, n)
      def element(guide) = new(:element, guide)
      def max_items(n) = new(:max_items, n)
      def maximum(n) = new(:maximum, n)
      def min_items(n) = new(:min_items, n)
      def minimum(n) = new(:minimum, n)
      def range(r) = new(:range, r)
      def regex(pattern) = new(:regex, pattern)

      # Build a list of guides from keyword constraints (used by `property`).
      def build(**constraints)
        constraints.filter_map do |key, val|
          next if val.nil?
          raise ArgumentError, "Unknown property constraint: #{key.inspect}" unless CONSTRAINT_KEYS.include?(key)

          new(key, val)
        end
      end
    end

    # Apply this guide to a native property pointer.
    # @api private
    def convert_to_c(prop_ptr)
      guide_type = @type
      value = @value
      wrapped = false

      # An element guide applies its inner guide to array elements.
      if guide_type == :element
        inner = value
        guide_type = inner.type
        value = inner.value
        wrapped = true
      end

      case guide_type
      when :any_of
        add_any_of(prop_ptr, Array(value), wrapped)
      when :constant
        add_any_of(prop_ptr, [value], wrapped)
      when :count
        Library.FMGenerationSchemaPropertyAddCountGuide(prop_ptr, value.to_i, wrapped)
      when :max_items
        Library.FMGenerationSchemaPropertyAddMaxItemsGuide(prop_ptr, value.to_i)
      when :min_items
        Library.FMGenerationSchemaPropertyAddMinItemsGuide(prop_ptr, value.to_i)
      when :maximum
        Library.FMGenerationSchemaPropertyAddMaximumGuide(prop_ptr, value.to_f, wrapped)
      when :minimum
        Library.FMGenerationSchemaPropertyAddMinimumGuide(prop_ptr, value.to_f, wrapped)
      when :range
        min, max = range_bounds(value)
        Library.FMGenerationSchemaPropertyAddRangeGuide(prop_ptr, min.to_f, max.to_f, wrapped)
      when :regex
        Library.FMGenerationSchemaPropertyAddRegex(prop_ptr, value.to_s, wrapped)
      else
        raise InvalidGenerationSchemaError, "Unknown guide type: #{guide_type.inspect}"
      end
    end

    private

    def range_bounds(value)
      case value
      when Range then [value.begin, value.end]
      when Array then value
      else
        raise InvalidGenerationSchemaError, "range must be a Range or [min, max], got #{value.inspect}"
      end
    end

    def add_any_of(prop_ptr, values, wrapped)
      # Build a char** array; keep the MemoryPointers alive for the duration of the call.
      strings = values.map { |v| ::FFI::MemoryPointer.from_string(v.to_s) }
      array = ::FFI::MemoryPointer.new(:pointer, strings.size)
      array.write_array_of_pointer(strings)
      Library.FMGenerationSchemaPropertyAddAnyOfGuide(prop_ptr, array, values.size, wrapped)
    end
  end
end
