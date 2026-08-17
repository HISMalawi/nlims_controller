# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrderSearch do
  describe "o tracking number" do
    it "é um destino, não uma pesquisa" do
      order = create(:order)

      expect(described_class.new(q: order.tracking_number).exact_match).to eq(order)
    end

    it "não é um destino quando não é um tracking number" do
      create(:order)

      expect(described_class.new(q: "Ana").exact_match).to be_nil
    end

    it "não é um destino quando é bem formado mas não existe" do
      expect(described_class.new(q: "MZ-HCM-26229-9999").exact_match).to be_nil
    end
  end

  describe "o termo livre" do
    it "não procura por nome com menos de três letras, para não devolver meio registo" do
      create(:order, patient: create(:patient, name: "Ana Machava"))

      expect(described_class.new(q: "An").total).to be_zero
    end

    it "trata o sublinhado do LIKE como uma letra e não como um coringa" do
      create(:order, patient: create(:patient, name: "Ana Machava"))

      expect(described_class.new(q: "An_").total).to be_zero
    end
  end

  describe "sem critérios" do
    it "não se diz filtrada e devolve tudo" do
      create_list(:order, 2)
      search = described_class.new({})

      expect(search).not_to be_filtered
      expect(search.total).to eq(2)
    end
  end

  describe "as páginas" do
    it "nunca são menos de uma, mesmo sem resultados" do
      expect(described_class.new(q: "nada de nada").pages).to eq(1)
    end
  end
end
