# frozen_string_literal: true

# Guided (structured) generation into typed Ruby objects.
#   ruby -Ilib examples/guided_generation.rb

require "foundation_models"

class Cat
  include FoundationModels::Generable
  generable description: "An adorable rescue cat"

  property :name, String, description: "The cat's name"
  property :age, Integer, description: "Age in years", range: 0..20
  property :temperament, String, any_of: %w[playful shy affectionate independent]
  property :favorite_toys, [String], min_items: 1, description: "A few favorite toys"
end

session = FoundationModels::LanguageModelSession.new

cat = session.respond("Generate an adorable rescue cat.", generating: Cat)

puts "Name:        #{cat.name}"
puts "Age:         #{cat.age}"
puts "Temperament: #{cat.temperament}"
puts "Toys:        #{cat.favorite_toys.join(', ')}"
