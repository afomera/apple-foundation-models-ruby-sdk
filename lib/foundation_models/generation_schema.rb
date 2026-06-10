# frozen_string_literal: true

require "json"

module FoundationModels
  # Describes the structure of guided (structured) generation output.
  #
  # Usually produced from a {Generable} class via `MyClass.generation_schema`, but
  # can also be constructed directly from properties.
  class GenerationSchema < ManagedObject
    attr_reader :references

    # @param name [String] the schema/type name
    # @param description [String, nil]
    # @param properties [Array<GenerationProperty>]
    # @param references [Array<GenerationSchema>] nested schemas referenced by properties
    def initialize(name:, description: nil, properties: [], references: [], ptr: nil)
      @references = references # retained so nested schemas aren't GC'd while in use

      if ptr
        super(ptr)
        return
      end

      created = Library.FMGenerationSchemaCreate(name.to_s, description)
      references.each { |ref| Library.FMGenerationSchemaAddReferenceSchema(created, ref.ptr) }
      properties.each { |property| property.convert_to_c(created) }
      super(created)
    end

    # @return [Hash] the schema as a JSON-compatible Hash
    def to_h
      err_code = ::FFI::MemoryPointer.new(:int)
      err_desc = ::FFI::MemoryPointer.new(:pointer)
      json_ptr = Library.FMGenerationSchemaGetJSONString(ptr, err_code, err_desc)

      if json_ptr.nil? || json_ptr.null?
        raise FoundationModels.error_for_status(
          err_code.read_int,
          debug_description: read_out_string(err_desc),
        )
      end

      JSON.parse(Library.consume_string(json_ptr))
    end

    # @return [String] the schema as a JSON string
    def to_json(*_args) = JSON.generate(to_h)

    private

    # Read a `char **` out-parameter (the bridge strdup's it) and free it.
    def read_out_string(double_ptr)
      inner = double_ptr.read_pointer
      Library.consume_string(inner)
    end
  end
end
