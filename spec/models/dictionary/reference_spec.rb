# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::Reference do
  def resolve(value)
    described_class.resolve("test_types", value)
  end

  describe "a term the dictionary carries" do
    let!(:test_type) { create(:test_type, name: "Hemograma") }

    it "finds it by national code" do
      reference = resolve({ national_code: test_type.national_code })

      expect(reference).to be_known
      expect(reference.entry).to eq(test_type)
      expect(reference.label).to eq("Hemograma")
    end

    it "finds it by uuid" do
      expect(resolve({ uuid: test_type.uuid }).entry).to eq(test_type)
    end

    it "finds it by name" do
      expect(resolve({ name: "Hemograma" }).entry).to eq(test_type)
    end

    # A bare string is tried both ways: a client sending a code and a client
    # sending a name both mean "this is what I call the exam", and neither
    # should have to know which of the two this node stores it under.
    it "finds it from a bare string, whether that string is a code or a name" do
      expect(resolve("Hemograma").entry).to eq(test_type)
      expect(resolve(test_type.national_code).entry).to eq(test_type)
    end

    # Refusing on status is exactly the gate being removed: a retired entry is
    # still the closest thing this node knows to what was asked for.
    it "finds it even after it has been retired" do
      test_type.retire!(actor: "spec")

      expect(resolve({ national_code: test_type.national_code }).entry).to eq(test_type)
    end

    it "prefers the dictionary's own wording to the one the client sent" do
      reference = resolve({ national_code: test_type.national_code, name: "hemogramma" })

      expect(reference.label).to eq("Hemograma")
    end

    # A name two entries answer to says nothing about which was meant.
    it "does not guess between two entries sharing a name" do
      create(:test_type, name: "Hemograma")

      expect(resolve({ name: "Hemograma" })).not_to be_known
    end
  end

  describe "a term the dictionary does not carry" do
    it "keeps the code and the name it arrived with" do
      reference = resolve({ national_code: "MOZ-TT-9999", name: "Ferritina" })

      expect(reference).not_to be_known
      expect(reference).to be_present
      expect(reference.code).to eq("MOZ-TT-9999")
      expect(reference.label).to eq("Ferritina")
    end

    it "keeps a name given on its own" do
      expect(resolve("Ferritina").label).to eq("Ferritina")
    end

    it "is blank when nothing at all was named" do
      expect(resolve(nil)).to be_blank
      expect(resolve({})).to be_blank
      expect(resolve("  ")).to be_blank
    end

    it "names the code as well as the name when it has to be refused elsewhere" do
      expect(resolve({ national_code: "MOZ-TT-9999", name: "Ferritina" }).description)
        .to eq("MOZ-TT-9999 (Ferritina)")
    end
  end

  describe ".resolve!" do
    it "refuses a term that names nothing, saying which field" do
      expect { described_class.resolve!("test_types", nil, field: "tests[0].test_type") }
        .to raise_error(InvalidRequest) { |error| expect(error.field).to eq("tests[0].test_type") }
    end
  end

  # Strong parameters cannot declare a key as both a hash and a string, so a
  # bare string used to be dropped silently — an order sent with
  # `"specimen_type": "Sangue total"` was created with no specimen type and
  # nothing said so.
  describe ".expand" do
    it "turns every bare term into an object, at any depth" do
      params = ActionController::Parameters.new(
        "order" => { "specimen_type" => "Sangue total" },
        "tests" => [ { "test_type" => "Hemograma" }, { "test_type" => { "national_code" => "MOZ-TT-0001" } } ]
      )

      expanded = described_class.expand(params).to_unsafe_h

      expect(expanded.dig("order", "specimen_type")).to eq({ "name" => "Sangue total" })
      expect(expanded.dig("tests", 0, "test_type")).to eq({ "name" => "Hemograma" })
      expect(expanded.dig("tests", 1, "test_type")).to eq({ "national_code" => "MOZ-TT-0001" })
    end

    it "leaves everything that is not a term alone" do
      expanded = described_class.expand(ActionController::Parameters.new("order" => { "priority" => "urgent" }))

      expect(expanded.to_unsafe_h.dig("order", "priority")).to eq("urgent")
    end
  end
end
