# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::LoincMapping, mode: :national do
  it "aplica uma decisão e faz a entrada avançar de revisão" do
    entry = create(:test_type, name: "Hemoglobina")
    before = entry.revision
    path = worksheet([ [ "test_types", entry.national_code, "718-7" ] ])

    mapping = described_class.new(path: path, actor: "Ana Machava", catalogue: loinc_catalogue).call

    expect(mapping.applied).to eq(1)
    expect(entry.reload.loinc_code).to eq("718-7")
    expect(entry.revision).to be > before
  end

  it "não escreve nada numa simulação" do
    entry = create(:test_type)
    path = worksheet([ [ "test_types", entry.national_code, "718-7" ] ])

    mapping = described_class.new(path: path, actor: "Ana", catalogue: loinc_catalogue, dry_run: true).call

    expect(mapping.applied).to eq(1)
    expect(entry.reload.loinc_code).to be_nil
  end

  it "não aplica linha nenhuma quando uma delas está errada" do
    good = create(:test_type)
    other = create(:test_type)
    path = worksheet([
      [ "test_types", good.national_code, "718-7" ],
      [ "test_types", other.national_code, "718-8" ]
    ])

    mapping = described_class.new(path: path, actor: "Ana", catalogue: loinc_catalogue).call

    expect(mapping).to be_failed
    expect(good.reload.loinc_code).to be_nil
    expect(other.reload.loinc_code).to be_nil
  end

  it "recusa um código que o LOINC não publica" do
    entry = create(:test_type)
    path = worksheet([ [ "test_types", entry.national_code, "10101-4" ] ])

    mapping = described_class.new(path: path, actor: "Ana", catalogue: loinc_catalogue).call

    expect(mapping.rejected.sole.result).to eq(:unknown_code)
  end

  it "recusa um código que o LOINC retirou" do
    entry = create(:test_type)
    path = worksheet([ [ "test_types", entry.national_code, "5195-3" ] ])

    mapping = described_class.new(path: path, actor: "Ana", catalogue: loinc_catalogue).call

    expect(mapping.rejected.sole.result).to eq(:deprecated_code)
  end

  it "recusa uma entidade que não se cura" do
    department = create(:department)
    path = worksheet([ [ "departments", department.national_code, "718-7" ] ])

    mapping = described_class.new(path: path, actor: "Ana", catalogue: loinc_catalogue).call

    expect(mapping.rejected.sole.result).to eq(:not_curated)
  end

  it "recusa um código nacional que este nó não conhece" do
    path = worksheet([ [ "test_types", "MOZ-TT-9999", "718-7" ] ])

    mapping = described_class.new(path: path, actor: "Ana", catalogue: loinc_catalogue).call

    expect(mapping.rejected.sole.result).to eq(:not_found)
  end

  it "ignora as linhas que o curador deixou por preencher" do
    entry = create(:test_type)
    path = worksheet([
      [ "test_types", entry.national_code, "" ],
      [ "test_types", create(:test_type).national_code, "718-7" ]
    ])

    mapping = described_class.new(path: path, actor: "Ana", catalogue: loinc_catalogue).call

    expect(mapping.outcomes.length).to eq(1)
    expect(mapping.applied).to eq(1)
  end

  it "não repete o trabalho já feito" do
    entry = create(:test_type, loinc_code: "718-7")
    path = worksheet([ [ "test_types", entry.national_code, "718-7" ] ])

    mapping = described_class.new(path: path, actor: "Ana", catalogue: loinc_catalogue).call

    expect(mapping.applied).to be_zero
    expect(mapping.unchanged).to eq(1)
  end

  it "diz quando está a substituir uma decisão anterior, em vez de a absorver" do
    entry = create(:test_type, loinc_code: "718-7")
    path = worksheet([ [ "test_types", entry.national_code, "4544-3" ] ])

    mapping = described_class.new(path: path, actor: "Ana", catalogue: loinc_catalogue).call

    expect(mapping.outcomes.sole.detail).to eq("substitui 718-7")
    expect(entry.reload.loinc_code).to eq("4544-3")
  end

  it "sem versão LOINC carregada verifica a forma, e diz que é só isso que verifica" do
    entry = create(:test_type)
    path = worksheet([ [ "test_types", entry.national_code, "10101-4" ] ])

    mapping = described_class.new(path: path, actor: "Ana", catalogue: nil).call

    expect(mapping.applied).to eq(1)
    expect(entry.reload.loinc_code).to eq("10101-4")
  end

  it "recusa um ficheiro sem as colunas de que precisa" do
    path = worksheet([ [ "test_types", "MOZ-TT-0001" ] ], headers: %w[entity_type national_code])

    expect { described_class.new(path: path, actor: "Ana").call }
      .to raise_error(described_class::InvalidFile, /loinc_code/)
  end

  it "aceita a folha de trabalho tal como ela é escrita, com as colunas de candidatos" do
    entry = create(:test_type, name: "Hemoglobina")
    Dictionary::LoincSuggestions.new(catalogue: loinc_catalogue).write_csv("tmp/spec_worksheet.csv")

    path = Rails.root.join("tmp/spec_worksheet.csv")
    table = CSV.read(path, headers: true)
    table.each { |row| row["loinc_code"] = "718-7" }
    File.write(path, table.to_csv)

    mapping = described_class.new(path: path, actor: "Ana", catalogue: loinc_catalogue).call

    expect(mapping.applied).to eq(1)
    expect(entry.reload.loinc_code).to eq("718-7")
  end
end
