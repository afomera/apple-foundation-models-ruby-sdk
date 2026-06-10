# frozen_string_literal: true

require "json"

module FoundationModels
  # A stateful conversation with the on-device foundation model.
  #
  # Requests on a single session are serialized (the framework does not support
  # concurrent requests per session); create multiple sessions for concurrency.
  #
  # @example Basic
  #   session = FoundationModels::LanguageModelSession.new(instructions: "Be concise.")
  #   puts session.respond("What is a Swift?")
  #
  # @example Streaming
  #   session.stream_response("Tell me a story") { |snapshot| print snapshot }
  class LanguageModelSession < ManagedObject
    # @param instructions [String, nil] system instructions guiding the whole session
    # @param model [SystemLanguageModel, nil] a configured model (defaults to the system model)
    # @param tools [Array<Tool>, nil] tools the model may invoke
    def initialize(instructions: nil, model: nil, tools: nil, ptr: nil)
      @request_mutex = Mutex.new
      # Keep tool objects (and their native callbacks) alive for the session's lifetime.
      @tools = tools || []

      if ptr
        super(ptr)
        return
      end

      tool_array, tool_count = build_tool_array(@tools)
      created = Library.FMLanguageModelSessionCreateFromSystemLanguageModel(
        model&.ptr, instructions, tool_array, tool_count,
      )
      super(created)
    end

    # Resume a session from an exported transcript.
    #
    # @param transcript [Transcript] a transcript (e.g. from {#transcript} or {Transcript.from_json})
    # @param model [SystemLanguageModel, nil]
    # @param tools [Array<Tool>, nil] tools to make available for new calls (transcript tool
    #   mentions are historical only)
    # @return [LanguageModelSession]
    def self.from_transcript(transcript, model: nil, tools: nil)
      tool_list = tools || []
      array, count = build_tool_array_for(tool_list)
      created = Library.FMLanguageModelSessionCreateFromTranscript(transcript.ptr, model&.ptr, array, count)
      new(ptr: created, tools: tool_list)
    end

    # @api private
    def self.build_tool_array_for(tools)
      return [nil, 0] if tools.nil? || tools.empty?

      array = ::FFI::MemoryPointer.new(:pointer, tools.size)
      array.write_array_of_pointer(tools.map(&:ptr))
      [array, tools.size]
    end

    # @return [Boolean] whether a request is currently in flight
    def responding?
      Library.FMLanguageModelSessionIsResponding(@ptr)
    end

    # @return [String] the session's conversation history as a JSON string
    def transcript_json
      err_code = ::FFI::MemoryPointer.new(:int)
      err_desc = ::FFI::MemoryPointer.new(:pointer)
      json_ptr = Library.FMLanguageModelSessionGetTranscriptJSONString(@ptr, err_code, err_desc)

      if json_ptr.nil? || json_ptr.null?
        raise FoundationModels.error_for_status(
          err_code.read_int,
          debug_description: Library.consume_string(err_desc.read_pointer),
        )
      end

      Library.consume_string(json_ptr)
    end

    # @return [Transcript] a snapshot of the session's conversation history
    def transcript
      Transcript.from_json(transcript_json)
    end

    # Generate a response (blocking).
    #
    # With no generation constraints, returns a String. With `generating:` (a
    # {Generable} class), returns an instance of that class. With `schema:` (a
    # {GenerationSchema}) or `json_schema:` (a Hash/JSON string), returns a
    # {GeneratedContent}.
    #
    # @param prompt [String, Attachment, Array] the prompt
    # @param generating [Class, nil] a Generable class for typed structured output
    # @param schema [GenerationSchema, nil] an explicit schema
    # @param json_schema [Hash, String, nil] a raw JSON schema
    # @param options [GenerationOptions, nil]
    # @param timeout [Numeric, nil] cancel and raise {TimeoutError} after this many seconds
    # @return [String, Object, GeneratedContent]
    # @raise [TimeoutError] if the request exceeds `timeout`
    def respond(prompt, generating: nil, schema: nil, json_schema: nil, options: nil, timeout: nil)
      provided = [generating, schema, json_schema].compact
      raise ArgumentError, "Specify at most one of: generating, schema, json_schema" if provided.length > 1

      @request_mutex.synchronize do
        if generating
          gen_schema = generating.generation_schema
          content = run_structured(prompt, options, timeout) do |composed, options_json, callback|
            Library.FMLanguageModelSessionRespondWithSchema(
              @ptr, composed, gen_schema.ptr, options_json, nil, callback,
            )
          end
          generating.from_generated_content(content)
        elsif schema
          run_structured(prompt, options, timeout) do |composed, options_json, callback|
            Library.FMLanguageModelSessionRespondWithSchema(
              @ptr, composed, schema.ptr, options_json, nil, callback,
            )
          end
        elsif json_schema
          schema_json = json_schema.is_a?(String) ? json_schema : JSON.generate(json_schema)
          run_structured(prompt, options, timeout) do |composed, options_json, callback|
            Library.FMLanguageModelSessionRespondWithSchemaFromJSON(
              @ptr, composed, schema_json, options_json, nil, callback,
            )
          end
        else
          run_respond(prompt, options, timeout)
        end
      end
    end

    # Stream a text response as cumulative snapshots.
    #
    # Yields progressively longer snapshots (each contains the full text so far).
    # Without a block, returns an Enumerator.
    #
    # @param prompt [String, Attachment, Array]
    # @param options [GenerationOptions, nil]
    # @param timeout [Numeric, nil] cancel and raise {TimeoutError} if no snapshot arrives
    #   within this many seconds
    # @yieldparam snapshot [String]
    # @return [Enumerator, nil]
    def stream_response(prompt, options: nil, timeout: nil, &block)
      return enum_for(:stream_response, prompt, options: options, timeout: timeout) unless block

      @request_mutex.synchronize { run_stream(prompt, options, timeout, &block) }
    end

    private

    def run_respond(prompt, options, timeout)
      queue = Thread::Queue.new

      callback = ::FFI::Function.new(:void, %i[int pointer size_t pointer]) do |status, content_ptr, length, _user_info|
        queue.push([status, read_callback_string(content_ptr, length)])
      end

      composed = Prompt.compose(prompt)
      options_json = options && JSON.generate(options.to_h)

      task = Library.FMLanguageModelSessionRespond(@ptr, composed, options_json, nil, callback)

      begin
        status, text = await_result(queue, task, timeout)
      ensure
        Library.FMRelease(composed)
        Library.FMRelease(task) unless task.nil? || task.null?
      end

      unless status == GenerationErrorCode::SUCCESS
        raise FoundationModels.error_for_status(status, debug_description: text)
      end

      text
    end

    # Wait for a single-callback result, cancelling the native task on timeout or
    # thread interruption. Returns the [status, payload] pushed by the callback.
    def await_result(queue, task, timeout)
      result = queue.pop(timeout: timeout)
      if result.nil?
        # A nil result only occurs on timeout (the callback always pushes an array).
        cancel_active_task(task)
        raise TimeoutError, "request timed out after #{timeout}s"
      end
      result
    rescue Exception => e # interrupted while waiting (Thread#raise, etc.) # rubocop:disable Lint/RescueException
      cancel_active_task(task) unless e.is_a?(TimeoutError)
      raise
    end

    # Cancel a native task and wait until the session stops responding, so the task's
    # callback can't fire after we release it. Resets session state afterward.
    def cancel_active_task(task)
      return if task.nil? || task.null?

      Library.FMTaskCancel(task)
      wait_until_idle
      Library.FMLanguageModelSessionReset(@ptr)
    end

    def wait_until_idle(max_wait: 1.0, interval: 0.01)
      waited = 0.0
      while responding? && waited < max_wait
        sleep(interval)
        waited += interval
      end
    end

    def run_stream(prompt, options, timeout, &)
      queue = Thread::Queue.new
      error_ref = [nil] # mutable cell so the callback can hand an error back
      terminal = Object.new # unique end-of-stream sentinel (distinct from nil = timeout)

      callback = ::FFI::Function.new(:void, %i[int pointer size_t pointer]) do |status, content_ptr, length, _user_info|
        if status == GenerationErrorCode::SUCCESS
          text = read_callback_string(content_ptr, length)
          queue.push(text.nil? ? terminal : text) # nil content => end-of-stream
        else
          error_ref[0] = FoundationModels.error_for_status(
            status, debug_description: read_callback_string(content_ptr, length),
          )
          queue.push(terminal)
        end
      end

      composed = Prompt.compose(prompt)
      options_json = options && JSON.generate(options.to_h)

      stream = Library.FMLanguageModelSessionStreamResponse(@ptr, composed, options_json)
      if stream.nil? || stream.null?
        Library.FMRelease(composed)
        raise FoundationModels::Error, "Failed to create response stream"
      end

      # Iterate dispatches a detached task and returns immediately; the callback fires
      # per snapshot from a Swift concurrency thread, ending with a nil-content snapshot.
      Library.FMLanguageModelSessionResponseStreamIterate(stream, nil, callback)
      consume_stream(stream, composed, queue, terminal, timeout, error_ref, &)
    end

    def consume_stream(stream, composed, queue, terminal, timeout, error_ref)
      completed = false
      stream_released = false

      begin
        loop do
          item = queue.pop(timeout: timeout) # GVL released while waiting
          raise TimeoutError, "stream timed out after #{timeout}s waiting for a snapshot" if item.nil?

          break (completed = true) if item.equal?(terminal)

          yield item
        end
      ensure
        unless completed
          # Early exit (break, timeout, or exception): releasing the stream triggers its
          # deinit, which cancels the native task. Drain until the task's final callback
          # fires so our FFI callback is never invoked after it could be collected.
          Library.FMRelease(stream)
          stream_released = true
          drain_stream_queue(queue, terminal)
          Library.FMLanguageModelSessionReset(@ptr)
          error_ref[0] = nil # a cancelled stream's terminal error is expected; don't surface it
        end
        Library.FMRelease(stream) unless stream_released
        Library.FMRelease(composed)
      end

      raise error_ref[0] if error_ref[0]

      nil
    end

    def drain_stream_queue(queue, terminal, max_wait: 2.0)
      waited = 0.0
      while waited < max_wait
        item = queue.pop(timeout: 0.05)
        if item.nil?
          waited += 0.05
          next
        end
        break if item.equal?(terminal)
      end
    end

    # Dispatch a guided-generation request. The block starts the native task and
    # returns the FMTaskRef. Returns a GeneratedContent on success.
    def run_structured(prompt, options, timeout = nil)
      queue = Thread::Queue.new

      callback = ::FFI::Function.new(:void, %i[int pointer pointer]) do |status, content_ref, _user_info|
        queue.push([status, content_ref])
      end

      composed = Prompt.compose(prompt)
      options_json = options && JSON.generate(options.to_h)

      task = yield(composed, options_json, callback)

      begin
        status, content_ref = await_result(queue, task, timeout)
      ensure
        Library.FMRelease(composed)
        Library.FMRelease(task) unless task.nil? || task.null?
      end

      if status == GenerationErrorCode::SUCCESS
        GeneratedContent.new(ptr: content_ref)
      else
        debug = nil
        if content_ref && !content_ref.null?
          # Wrapping takes ownership; the debug content is released when it goes out of scope.
          debug = GeneratedContent.new(ptr: content_ref).to_h.to_s
        end
        raise FoundationModels.error_for_status(status, debug_description: debug)
      end
    end

    def read_callback_string(content_ptr, length)
      return nil if content_ptr.nil? || content_ptr.null? || length.zero?

      content_ptr.read_string(length).force_encoding(Encoding::UTF_8)
    end

    def build_tool_array(tools)
      self.class.build_tool_array_for(tools)
    end
  end
end
