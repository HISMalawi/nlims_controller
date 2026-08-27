# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::SnapshotSource do
  describe "taking one" do
    let(:live) { MlabFixtureSource.load }
    let(:path) { "tmp/spec_catalog.json" }

    after { FileUtils.rm_f(Rails.root.join(path)) }

    it "reads back exactly what the live source answered" do
      described_class.write(live, path)
      snapshot = described_class.load(path)

      described_class::ENTITIES.each do |entity|
        expect(snapshot.public_send(entity)).to eq(live.public_send(entity)), "#{entity} did not survive the round trip"
      end
    end

    it "says where it came from and when it was taken" do
      described_class.write(live, path)

      expect(described_class.load(path).describe).to match(%r{\Atmp/spec_catalog\.json de \d{4}-\d{2}-\d{2}T})
    end

    it "refuses to load a catalogue that is not there" do
      expect { described_class.load("db/dictionary/nao_existe.json") }
        .to raise_error(described_class::Missing, /dictionary:snapshot/)
    end
  end

  describe "the catalogue shipped with the release" do
    subject(:catalogue) { described_class.load }

    def ids(entity) = catalogue.public_send(entity).map { |row| row[:id] }

    it "carries every entity the importer reads" do
      described_class::ENTITIES.each do |entity|
        expect(catalogue.public_send(entity)).to be_an(Array), "#{entity} is missing from the catalogue"
      end

      expect(catalogue.test_types).not_to be_empty
    end

    it "identifies each row once" do
      %i[departments specimen_types drugs organisms indicators test_types test_panels].each do |entity|
        expect(ids(entity)).to eq(ids(entity).uniq), "#{entity} carries the same id twice"
      end
    end

    it "links only to rows it carries, so nothing is imported half-connected" do
      {
        organism_drug_links: { organism_id: :organisms, drug_id: :drugs },
        indicator_ranges: { test_indicator_id: :indicators },
        test_type_indicator_links: { test_type_id: :test_types, indicator_id: :indicators },
        test_type_specimen_links: { test_type_id: :test_types, specimen_type_id: :specimen_types },
        test_type_organism_links: { test_type_id: :test_types, organism_id: :organisms },
        test_panel_test_type_links: { test_panel_id: :test_panels, test_type_id: :test_types }
      }.each do |link_table, columns|
        columns.each do |column, entity|
          dangling = catalogue.public_send(link_table).map { |row| row[column] } - ids(entity)
          expect(dangling).to be_empty, "#{link_table}.#{column} points at #{entity} that are not here: #{dangling}"
        end
      end
    end

    it "gives every test type a department the catalogue also carries" do
      expect(catalogue.test_types.map { |row| row[:department_id] }.uniq - ids(:departments)).to be_empty
    end
  end
end
