# frozen_string_literal: true

# Letting the model call a Ruby tool during generation.
#   ruby -Ilib examples/tools.rb

require "foundation_models"

class WeatherArgs
  include FoundationModels::Generable
  property :city, String, description: "The city to get weather for"
end

class WeatherTool < FoundationModels::Tool
  tool_name "get_weather"
  description "Get the current weather for a city. Use this for any weather question."
  arguments WeatherArgs

  def call(args)
    city = args.value(String, :city)
    # A real tool would call a weather API here.
    "It is currently 72°F and sunny in #{city}."
  end
end

session = FoundationModels::LanguageModelSession.new(
  instructions: "You are a helpful assistant. Use tools when relevant.",
  tools: [WeatherTool.new],
)

puts session.respond("What's the weather like in Denver, CO right now?")
