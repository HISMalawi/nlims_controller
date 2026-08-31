# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::LoincCatalogue, mode: :national do
  it "lê a versão LOINC do ficheiro que lhe dão" do
    expect(loinc_catalogue.size).to eq(8)
    expect(loinc_catalogue.fetch("718-7").label).to eq("Hemoglobin [Mass/volume] in Blood")
  end

  it "recusa-se a inventar um caminho que não existe" do
    expect { described_class.from_path("tmp/nao-existe.csv") }
      .to raise_error(described_class::MissingFile, /nao-existe/)
  end

  it "sabe o que o LOINC retirou" do
    expect(loinc_catalogue.fetch("5195-3")).to be_deprecated
    expect(loinc_catalogue.fetch("718-7")).not_to be_deprecated
  end

  it "procura por palavras e nunca propõe um código retirado" do
    expect(loinc_catalogue.search(%w[hemoglobin]).map(&:code)).to eq([ "718-7" ])
    expect(loinc_catalogue.search(%w[hepatitis])).to be_empty
  end
end
