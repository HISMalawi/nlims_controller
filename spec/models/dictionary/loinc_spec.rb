# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::Loinc do
  describe "o dígito de controlo" do
    # Real LOINC numbers. If the algorithm is implemented the wrong way round —
    # doubling the other set of digits — every one of these fails, which is the
    # whole reason they are here by name.
    it "aceita códigos LOINC verdadeiros" do
      %w[718-7 2160-0 4544-3 2345-7 6690-2 30341-2 14682-9].each do |code|
        expect(described_class.check_digit_valid?(code)).to be(true), "esperava que #{code} passasse"
      end
    end

    it "recusa um código com um carácter trocado" do
      expect(described_class.check_digit_valid?("718-8")).to be(false)
      expect(described_class.check_digit_valid?("719-7")).to be(false)
    end

    it "recusa o que não tem sequer a forma de um código" do
      [ "", nil, "LOINC-718-7", "718", "718-", "abc-1", "718–7" ].each do |value|
        expect(described_class.check_digit_valid?(value)).to be(false), "esperava que #{value.inspect} falhasse"
      end
    end
  end

  describe "as entidades curáveis" do
    it "inclui as que um código LOINC descreve" do
      expect(described_class).to be_curated("test_types")
      expect(described_class).to be_curated("indicators")
    end

    it "exclui as administrativas, que nunca teriam um" do
      expect(described_class).not_to be_curated("departments")
      expect(described_class).not_to be_curated("rejection_reasons")
      expect(described_class).not_to be_curated("test_panels")
    end
  end
end
