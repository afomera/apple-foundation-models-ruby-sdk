# frozen_string_literal: true

module FoundationModels
  # Fiber-friendly async wrapper around a {LanguageModelSession}.
  #
  # Obtained via {LanguageModelSession#async}. Inside an `Async { }` reactor, these
  # methods offload the blocking native work to a thread and yield the fiber (so other
  # async tasks keep running) until the result is ready. Outside a reactor they behave
  # like the blocking API.
  #
  # @example
  #   require "async"
  #   Async do
  #     answer = session.async.respond("Hello")
  #     session.async.stream_response("Tell me a story") { |snap| print snap }
  #   end
  class AsyncSession
    def initialize(session)
      @session = session
    end

    # Async counterpart of {LanguageModelSession#respond}.
    # @return [String, Object, GeneratedContent]
    def respond(prompt, **kwargs)
      await { @session.respond(prompt, **kwargs) }
    end

    # Async counterpart of {LanguageModelSession#stream_response}.
    #
    # Yields cumulative snapshots without blocking the reactor. Returns the final text.
    # @return [String, nil]
    def stream_response(prompt, options: nil, timeout: nil)
      return enum_for(:stream_response, prompt, options: options, timeout: timeout) unless block_given?

      queue = Thread::Queue.new
      read, write = IO.pipe
      error = nil

      worker = Thread.new do
        @session.stream_response(prompt, options: options, timeout: timeout) do |snapshot|
          queue.push(snapshot)
          write.write(".")
        end
      rescue StandardError => e
        error = e
      ensure
        queue.close
        write.close
      end

      last = nil
      loop do
        break if read.read(1).nil? # pipe closed -> stream finished

        until queue.empty?
          last = queue.pop
          yield last
        end
      end
      read.close
      worker.join
      raise error if error

      last
    end

    private

    # Run a blocking block on a worker thread, yielding the current fiber (when inside
    # an Async reactor) until it completes.
    def await
      read, write = IO.pipe
      result = nil
      error = nil

      Thread.new do
        result = yield
      rescue Exception => e # rubocop:disable Lint/RescueException
        error = e
      ensure
        write.close
      end

      read.read(1) # fiber-scheduler-aware: yields the fiber inside Async, blocks otherwise
      read.close
      raise error if error

      result
    end
  end

  class LanguageModelSession
    # @return [AsyncSession] a fiber-friendly proxy for this session
    def async
      AsyncSession.new(self)
    end
  end
end
