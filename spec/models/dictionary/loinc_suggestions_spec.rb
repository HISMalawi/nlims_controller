# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::LoincSuggestions, mode: :national do
  it "encontra o candidato inglês a partir do nome português" do
    create(:test_type, name: "Hemoglobina")

    row = described_class.new(catalogue: loinc_catalogue).rows.sole

    expect(row[1]).to match(/\AMOZ-TT-/)
    expect(row[4]).to eq("718-7")
  end

  it "deixa a coluna de decisão vazia mesmo quando tem a certeza" do
    create(:test_type, name: "Hemoglobina")

    expect(described_class.new(catalogue: loinc_catalogue).rows.sole[3]).to be_nil
  end

  it "ignora os acentos, que a lista escreve das duas maneiras" do
    create(:indicator, name: "Creatinina")

    expect(described_class.new(catalogue: loinc_catalogue).rows.sole[4]).to be_present
  end

  it "não inventa candidatos para o que não reconhece" do
    create(:test_type, name: "Coisa nenhuma zzz")

    expect(described_class.new(catalogue: loinc_catalogue).rows.sole[4]).to be_nil
  end
end
