# frozen_string_literal: true

module FoundationModels
  # Mixin that turns a plain Ruby class into a structured-generation type.
  #
  # @example
  #   class Cat
  #     include FoundationModels::Generable
  #     generable description: "An adorable rescue cat"
  #     property :name, String
  #     property :age,  Integer, description: "Age in years", range: 0..20
  #     property :toys, [String], min_items: 1
  #   end
  #
  #   cat = session.respond("Generate a rescue cat", generating: Cat)
  #   cat.name # => "Whiskers"
  module Generable
    def self.included(base)
      base.extend(ClassMethods)
      base.instance_variable_set(:@fm_properties, [])
      base.instance_variable_set(:@fm_description, nil)
      base.instance_variable_set(:@fm_schema_name, nil)
    end

    module ClassMethods
      # @return [Array<GenerationProperty>]
      def fm_properties = @fm_properties

      def fm_description = @fm_description

      # Schema/type name: an explicit name, or the demodulized class name.
      def fm_schema_name
        @fm_schema_name || name.to_s.split("::").last
      end

      # Configure type-level metadata.
      def generable(description: nil, name: nil)
        @fm_description = description
        @fm_schema_name = name
      end

      # Declare a generated property.
      #
      # @param prop_name [Symbol] the property name (also defines an accessor)
      # @param type [Class, Symbol, Array] the property type (see {TypeConversion})
      # @param description [String, nil]
      # @param optional [Boolean]
      # @param constraints [Hash] guide constraints (any_of:, range:, regex:, min_items:, ...)
      def property(prop_name, type, description: nil, optional: false, **constraints)
        guides = GenerationGuide.build(**constraints)
        @fm_properties << GenerationProperty.new(
          name: prop_name, type: type, description: description, guides: guides, optional: optional,
        )
        attr_accessor prop_name
      end

      # Build the {GenerationSchema} for this type (including nested references).
      def generation_schema
        seen = {}
        references = []
        @fm_properties.each do |property|
          nested = property.referenced_generable
          next if nested.nil? || nested == self # skip self-references

          key = nested.fm_schema_name
          next if seen[key]

          seen[key] = true
          references << nested.generation_schema
        end

        GenerationSchema.new(
          name: fm_schema_name,
          description: fm_description,
          properties: @fm_properties,
          references: references,
        )
      end

      # Build an instance from generated content (bypasses #initialize).
      def from_generated_content(content)
        object = allocate
        @fm_properties.each do |property|
          object.instance_variable_set("@#{property.name}", content.value(property.type, property.name))
        end
        object
      end
    end
  end
end
