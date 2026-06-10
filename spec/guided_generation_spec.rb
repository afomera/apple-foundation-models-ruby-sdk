# frozen_string_literal: true

require "spec_helper"

# Test fixtures
class SpecCat
  include FoundationModels::Generable
  generable description: "An adorable rescue cat"
  property :name, String, description: "The cat name"
  property :age, Integer, description: "Age in years", range: 0..20
  property :favorite_toys, [String], min_items: 1
end

class SpecShelter
  include FoundationModels::Generable
  generable description: "An animal shelter"
  property :shelter_name, String
  property :cats, [SpecCat], description: "Cats available for adoption"
end

RSpec.describe FoundationModels::GenerationSchema do
  describe "schema construction (no device required)" do
    it "produces a JSON-schema hash with the right types" do
      schema = SpecCat.generation_schema.to_h
      expect(schema["type"]).to eq("object")
      expect(schema["properties"]["name"]["type"]).to eq("string")
      expect(schema["properties"]["age"]["type"]).to eq("integer")
      expect(schema["properties"]["favorite_toys"]["type"]).to eq("array")
    end

    it "translates a range guide into minimum/maximum" do
      age = SpecCat.generation_schema.to_h["properties"]["age"]
      expect(age["minimum"]).to eq(0)
      expect(age["maximum"]).to eq(20)
    end

    it "translates min_items into minItems" do
      toys = SpecCat.generation_schema.to_h["properties"]["favorite_toys"]
      expect(toys["minItems"]).to eq(1)
    end

    it "includes the description" do
      expect(SpecCat.generation_schema.to_h["description"]).to eq("An adorable rescue cat")
    end

    it "builds nested generable schemas without raising" do
      expect { SpecShelter.generation_schema.to_h }.not_to raise_error
    end
  end

  describe "type conversion" do
    it "maps Ruby types to schema type strings" do
      tc = FoundationModels::TypeConversion
      expect(tc.type_name(String)).to eq("string")
      expect(tc.type_name(Integer)).to eq("integer")
      expect(tc.type_name(Float)).to eq("number")
      expect(tc.type_name(FoundationModels::Boolean)).to eq("boolean")
      expect(tc.type_name([String])).to eq("array<string>")
    end

    it "rejects an array type without a single element type" do
      expect { FoundationModels::TypeConversion.type_name([]) }
        .to raise_error(FoundationModels::InvalidGenerationSchemaError)
    end
  end
end

RSpec.describe "Guided generation", :device do
  let(:session) { FoundationModels::LanguageModelSession.new }

  it "returns a typed Generable instance" do
    cat = session.respond("Generate a rescue cat named Mochi.", generating: SpecCat)
    expect(cat).to be_a(SpecCat)
    expect(cat.name).to be_a(String)
    expect(cat.age).to be_a(Integer)
    expect(cat.favorite_toys).to be_an(Array)
  end

  it "returns GeneratedContent for an explicit schema" do
    content = session.respond("Generate a cat.", schema: SpecCat.generation_schema)
    expect(content).to be_a(FoundationModels::GeneratedContent)
    expect(content.value(String, :name)).to be_a(String)
  end

  it "supports raw FM-dialect JSON schemas" do
    schema = {
      "type" => "object", "title" => "Color", "additionalProperties" => false,
      "properties" => { "color" => { "type" => "string" } },
      "required" => ["color"], "x-order" => ["color"],
    }
    content = session.respond("Pick a primary color.", json_schema: schema)
    expect(content.value(String, :color)).to be_a(String)
  end

  it "populates nested generables" do
    shelter = session.respond("Generate a shelter with two cats.", generating: SpecShelter)
    expect(shelter).to be_a(SpecShelter)
    expect(shelter.cats).to be_an(Array)
    expect(shelter.cats.first).to be_a(SpecCat) unless shelter.cats.empty?
  end

  it "rejects specifying more than one generation constraint" do
    expect { session.respond("hi", generating: SpecCat, schema: SpecCat.generation_schema) }
      .to raise_error(ArgumentError)
  end
end
