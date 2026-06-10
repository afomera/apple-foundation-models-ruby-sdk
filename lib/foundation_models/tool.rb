# frozen_string_literal: true

module FoundationModels
  # Base class for tools the model can invoke during generation.
  #
  # Subclasses declare a name, description, and an arguments schema (a {Generable}
  # class), and implement {#call}.
  #
  # @example
  #   class CalculatorArgs
  #     include FoundationModels::Generable
  #     property :a, Float, description: "first operand"
  #     property :b, Float, description: "second operand"
  #   end
  #
  #   class Calculator < FoundationModels::Tool
  #     tool_name "add"
  #     description "Add two numbers"
  #     arguments CalculatorArgs
  #
  #     def call(args)
  #       (args.value(Float, :a) + args.value(Float, :b)).to_s
  #     end
  #   end
  #
  #   session = FoundationModels::LanguageModelSession.new(tools: [Calculator.new])
  class Tool < ManagedObject
    class << self
      # Get/set the tool's name.
      def tool_name(value = nil)
        value.nil? ? @tool_name : (@tool_name = value)
      end

      # Get/set the human-readable description.
      def description(value = nil)
        value.nil? ? @description : (@description = value)
      end

      # Get/set the arguments schema source (a Generable class or a GenerationSchema).
      def arguments(value = nil)
        value.nil? ? @arguments : (@arguments = value)
      end

      # Inherit DSL values into subclasses that don't override them.
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@tool_name, @tool_name)
        subclass.instance_variable_set(:@description, @description)
        subclass.instance_variable_set(:@arguments, @arguments)
      end
    end

    # @return [String]
    def name = self.class.tool_name

    # @return [String]
    def description = self.class.description

    # @return [GenerationSchema]
    def arguments_schema
      source = self.class.arguments
      raise FoundationModels::Error, "#{self.class} must declare `arguments <Generable>`" if source.nil?

      source.is_a?(GenerationSchema) ? source : source.generation_schema
    end

    def initialize
      validate!

      # Keep the schema and the FFI callback alive for the tool's whole lifetime.
      @schema = arguments_schema
      @callback = ::FFI::Function.new(:void, %i[pointer uint]) do |content_ref, call_id|
        handle_call(content_ref, call_id)
      end

      err_code = ::FFI::MemoryPointer.new(:int)
      err_desc = ::FFI::MemoryPointer.new(:pointer)
      created = Library.FMBridgedToolCreate(name, description, @schema.ptr, @callback, err_code, err_desc)

      if created.nil? || created.null?
        desc = read_out_string(err_desc)
        raise FoundationModels.error_for_status(err_code.read_int, debug_description: desc)
      end

      super(created)
    end

    # Execute the tool. Subclasses must implement this.
    #
    # @param args [GeneratedContent] the parsed tool arguments
    # @return [String] result returned to the model
    def call(_args)
      raise NotImplementedError, "#{self.class} must implement #call(args)"
    end

    private

    # Invoked from a Swift concurrency thread when the model calls the tool.
    #
    # IMPORTANT: this callback must return *before* FMBridgedToolFinishCall is invoked.
    # The Swift side registers its continuation only after our callback returns, so we
    # run the tool body on a separate thread and finish the call from there. Calling
    # FinishCall synchronously here would deadlock (the continuation isn't registered yet).
    def handle_call(content_ref, call_id)
      args = GeneratedContent.new(ptr: content_ref) # ownership transferred (passRetained)

      Thread.new do
        output =
          begin
            result = call(args)
            result.is_a?(String) ? result : result.to_s
          rescue StandardError => e
            "Tool error: #{e.message}"
          end
        Library.FMBridgedToolFinishCall(@ptr, call_id, output)
      end
    end

    def validate!
      raise FoundationModels::Error, "#{self.class} must declare `tool_name`" if name.nil?
      raise FoundationModels::Error, "#{self.class} must declare `description`" if description.nil?
    end

    def read_out_string(double_ptr)
      Library.consume_string(double_ptr.read_pointer)
    end
  end
end
