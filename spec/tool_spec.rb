# frozen_string_literal: true

require "spec_helper"

class SpecWeatherArgs
  include FoundationModels::Generable
  property :city, String, description: "the city to look up"
end

class SpecWeatherTool < FoundationModels::Tool
  tool_name "get_weather"
  description "Get the current weather for a city. Use this for any weather question."
  arguments SpecWeatherArgs

  attr_reader :called_with

  def call(args)
    @called_with = args.value(String, :city)
    "It is 72F and sunny in #{@called_with}."
  end
end

RSpec.describe FoundationModels::Tool do
  it "can be constructed and exposes its metadata" do
    tool = SpecWeatherTool.new
    expect(tool.name).to eq("get_weather")
    expect(tool.description).to include("weather")
    expect(tool.arguments_schema).to be_a(FoundationModels::GenerationSchema)
  end

  it "raises if name/description are not declared" do
    klass = Class.new(FoundationModels::Tool) { arguments SpecWeatherArgs }
    expect { klass.new }.to raise_error(FoundationModels::Error, /tool_name/)
  end

  describe "invocation", :device do
    it "is invoked by the model and its result informs the answer" do
      tool = SpecWeatherTool.new
      session = FoundationModels::LanguageModelSession.new(
        instructions: "You are a helpful assistant. Use tools when relevant.",
        tools: [tool],
      )
      answer = session.respond("What is the weather in Cupertino right now?")
      expect(answer).to be_a(String)
      expect(tool.called_with).to match(/cupertino/i)
    end
  end
end
