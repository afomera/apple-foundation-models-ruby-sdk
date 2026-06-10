# frozen_string_literal: true

require "spec_helper"

RSpec.describe FoundationModels::GenerationOptions do
  it "serializes an empty options object to an empty hash" do
    expect(described_class.new.to_h).to eq({})
  end

  it "serializes temperature and maximum_response_tokens" do
    opts = described_class.new(temperature: 0.7, maximum_response_tokens: 500)
    expect(opts.to_h).to eq("temperature" => 0.7, "maximum_response_tokens" => 500)
  end

  it "serializes greedy sampling" do
    opts = described_class.new(sampling: FoundationModels::SamplingMode.greedy)
    expect(opts.to_h).to eq("sampling" => { "mode" => "greedy" })
  end

  it "serializes random sampling with string-encoded numeric fields (parity with Python)" do
    opts = described_class.new(
      sampling: FoundationModels::SamplingMode.random(top: 50, seed: 42),
    )
    expect(opts.to_h).to eq(
      "sampling" => { "mode" => "random", "top_k" => "50", "seed" => "42" },
    )
  end

  it "serializes nucleus (probability_threshold) sampling as top_p string" do
    opts = described_class.new(sampling: FoundationModels::SamplingMode.random(probability_threshold: 0.9))
    expect(opts.to_h["sampling"]).to eq("mode" => "random", "top_p" => "0.9")
  end

  it "rejects negative temperature" do
    expect { described_class.new(temperature: -0.1) }.to raise_error(ArgumentError)
  end

  it "rejects non-positive maximum_response_tokens" do
    expect { described_class.new(maximum_response_tokens: 0) }.to raise_error(ArgumentError)
  end
end

RSpec.describe FoundationModels::SamplingMode do
  it "rejects specifying both top and probability_threshold" do
    expect { described_class.random(top: 10, probability_threshold: 0.5) }.to raise_error(ArgumentError)
  end

  it "rejects a non-positive top" do
    expect { described_class.random(top: 0) }.to raise_error(ArgumentError)
  end

  it "rejects an out-of-range probability_threshold" do
    expect { described_class.random(probability_threshold: 1.5) }.to raise_error(ArgumentError)
  end
end
