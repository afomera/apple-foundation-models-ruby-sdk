# frozen_string_literal: true

module FoundationModels
  # Defines how tokens are sampled from the model's probability distribution.
  #
  # Construct via {SamplingMode.greedy} or {SamplingMode.random}.
  class SamplingMode
    GREEDY = "greedy"
    RANDOM = "random"

    attr_reader :mode_type, :top, :probability_threshold, :seed

    def initialize(mode_type:, top: nil, probability_threshold: nil, seed: nil)
      @mode_type = mode_type
      @top = top
      @probability_threshold = probability_threshold
      @seed = seed
    end

    # Always choose the most likely token (deterministic).
    def self.greedy
      new(mode_type: GREEDY)
    end

    # Randomly sample from high-probability tokens.
    #
    # @param top [Integer, nil] consider only the top-k most likely tokens
    # @param probability_threshold [Float, nil] nucleus sampling cumulative threshold (0.0–1.0)
    # @param seed [Integer, nil] seed for reproducible sampling
    def self.random(top: nil, probability_threshold: nil, seed: nil)
      if top && probability_threshold
        raise ArgumentError, "Cannot specify both 'top' and 'probability_threshold'. Choose one."
      end
      raise ArgumentError, "'top' must be a positive integer" if top && (!top.is_a?(Integer) || top <= 0)
      if probability_threshold && !(0.0..1.0).cover?(probability_threshold)
        raise ArgumentError, "'probability_threshold' must be between 0.0 and 1.0"
      end
      raise ArgumentError, "'seed' must be an integer" if seed && !seed.is_a?(Integer)

      new(mode_type: RANDOM, top: top, probability_threshold: probability_threshold, seed: seed)
    end
  end

  # Options that control how the model generates its response.
  #
  # @example
  #   FoundationModels::GenerationOptions.new(
  #     temperature: 0.7,
  #     sampling: FoundationModels::SamplingMode.random(top: 50, seed: 42),
  #     maximum_response_tokens: 500,
  #   )
  class GenerationOptions
    attr_reader :sampling, :temperature, :maximum_response_tokens

    def initialize(sampling: nil, temperature: nil, maximum_response_tokens: nil)
      if temperature && (!temperature.is_a?(Numeric) || temperature < 0.0)
        raise ArgumentError, "'temperature' must be a non-negative number"
      end
      if maximum_response_tokens && (!maximum_response_tokens.is_a?(Integer) || maximum_response_tokens <= 0)
        raise ArgumentError, "'maximum_response_tokens' must be a positive integer"
      end
      raise ArgumentError, "'sampling' must be a SamplingMode instance" if sampling && !sampling.is_a?(SamplingMode)

      @sampling = sampling
      @temperature = temperature
      @maximum_response_tokens = maximum_response_tokens
    end

    # Serialize to the Hash the native bridge expects (mirrors the Python SDK exactly,
    # including the string-encoded top_k/top_p/seed values).
    def to_h
      result = {}

      if sampling
        sampling_hash = { "mode" => sampling.mode_type }
        if sampling.mode_type == SamplingMode::RANDOM
          sampling_hash["top_k"] = sampling.top.to_s unless sampling.top.nil?
          sampling_hash["top_p"] = sampling.probability_threshold.to_s unless sampling.probability_threshold.nil?
          sampling_hash["seed"] = sampling.seed.to_s unless sampling.seed.nil?
        end
        result["sampling"] = sampling_hash
      end

      result["temperature"] = temperature unless temperature.nil?
      result["maximum_response_tokens"] = maximum_response_tokens unless maximum_response_tokens.nil?
      result
    end
  end
end
