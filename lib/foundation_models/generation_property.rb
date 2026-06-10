# frozen_string_literal: true

module FoundationModels
  # A single field within a {GenerationSchema}: a name, type, optional description,
  # and any {GenerationGuide} constraints.
  class GenerationProperty
    attr_reader :name, :type, :description, :guides, :optional

    def initialize(name:, type:, description: nil, guides: [], optional: false)
      @name = name.to_s
      @type = type
      @description = description
      @guides = guides
      @optional = optional
    end

    # Create the native property, attach guides, and add it to a schema pointer.
    # @api private
    def convert_to_c(schema_ptr)
      type_name = TypeConversion.type_name(@type)
      prop_ptr = Library.FMGenerationSchemaPropertyCreate(@name, @description, type_name, @optional)
      @guides.each { |guide| guide.convert_to_c(prop_ptr) }
      Library.FMGenerationSchemaAddProperty(schema_ptr, prop_ptr)
      Library.FMRelease(prop_ptr)
    end

    # The nested Generable class this property references (directly or as an array
    # element), or nil.
    # @api private
    def referenced_generable
      element = @type.is_a?(Array) ? @type.first : @type
      TypeConversion.generable_class?(element) ? element : nil
    end
  end
end
