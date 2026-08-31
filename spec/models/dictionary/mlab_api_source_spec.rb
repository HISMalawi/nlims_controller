# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::MlabApiSource do
  let(:database_source) { MlabFixtureSource.load }
  let(:transport) { MlabApiStub.new(database_source) }
  let(:source) { described_class.new(transport: transport, label: "http://mlab.example") }

  # The indicators the API can reach: one attached to no test never arrives,
  # because it arrives through the test that uses it.
  def linked_indicators
    ids = database_source.test_type_indicator_links.map { |link| link[:indicator_id] }

    database_source.indicators.select { |row| ids.include?(row[:id]) }
                   .map { |row| row.except(:test_indicator_type) }
  end

  describe "reading the same dictionary as the database" do
    %i[departments specimen_types drugs organisms organism_drug_links indicator_ranges
       test_types test_type_indicator_links test_type_specimen_links test_type_organism_links
       test_panels test_panel_test_type_links].each do |entity|
      it "answers #{entity} exactly as Dictionary::MlabSource would" do
        expect(source.public_send(entity)).to match_array(database_source.public_send(entity))
      end
    end

    it "answers the indicators the tests use, with their value types" do
      expect(source.indicators).to match_array(linked_indicators)
      expect(source.indicators.find { |row| row[:name] == "Hemoglobina" }[:value_type]).to eq("Numeric")
    end

    it "carries the turnaround time back as one string" do
      expect(source.test_types.find { |row| row[:id] == 1 }[:target_tat]).to eq("4 horas")
      expect(source.test_types.find { |row| row[:id] == 2 }[:target_tat]).to be_nil
    end

    it "names itself by the address it read" do
      expect(source.describe).to eq("http://mlab.example")
    end

    it "reads each test once, however many times the links are asked for" do
      source.test_type_indicator_links
      source.test_type_organism_links

      expect(transport.requests.count("/api/v1/test_types/1")).to eq(1)
    end
  end

  describe "importing through it" do
    let(:import) { Dictionary::MlabImporter.new(source: source).call }

    it "builds the same dictionary the database import builds" do
      import

      expect(Department.count).to eq(2)
      expect(SpecimenType.count).to eq(3)
      expect(Drug.count).to eq(2)
      expect(Organism.count).to eq(2)
      expect(TestType.count).to eq(3)
      expect(TestPanel.count).to eq(2)
    end

    it "leaves out an indicator no test uses, which the API never serves" do
      import

      expect(Indicator.count).to eq(3)
      expect(Indicator.pluck(:name)).to contain_exactly("Hemoglobina", "Leucócitos", "Cultura")
    end

    it "keeps the mLab ids, so a later database import finds the same entries" do
      import

      test_type = TestType.find_by(name: "Hemograma completo")
      expect(ExternalMapping.resolve(system: "mlab", entity_type: "test_types", external_code: "1"))
        .to eq(test_type.uuid)
    end

    it "carries the links across" do
      import

      test_type = TestType.find_by(name: "Hemograma completo")
      expect(test_type.indicators.pluck(:name)).to contain_exactly("Hemoglobina", "Leucócitos")
      expect(test_type.specimen_types.pluck(:name)).to contain_exactly("Sangue total")
      expect(Indicator.find_by(name: "Hemoglobina").indicator_ranges.count).to eq(3)
    end
  end

  describe "a test whose department mLab has retired" do
    let(:transport) { MlabApiStub.new(database_source, hidden_departments: [ 2 ]) }

    it "still imports the test, because the laboratories are running it" do
      Dictionary::MlabImporter.new(source: source).call

      expect(TestType.find_by(name: "Cultura de sangue")).to be_present
    end

    it "does not ask for a detail the API will refuse" do
      source.test_type_indicator_links

      expect(transport.asked_for?("/api/v1/test_types/3")).to be(false)
    end

    it "says which test it is and what is missing from it" do
      source.test_type_indicator_links

      expect(source.warnings).to contain_exactly(
        a_string_including("Cultura de sangue", "departamento 2", "sem indicadores nem organismos")
      )
    end

    it "reads the specimen links of that test all the same" do
      expect(source.test_type_specimen_links).to match_array(database_source.test_type_specimen_links)
    end
  end

  describe "an endpoint that paginates" do
    let(:transport) { MlabApiStub.new(database_source, per_page: 1) }

    it "follows the pages to the end rather than importing the first one" do
      expect(source.test_type_specimen_links).to match_array(database_source.test_type_specimen_links)
    end
  end

  describe "an organism a test names but the organism list does not hold" do
    before do
      allow(transport).to receive(:get).and_wrap_original do |original, path, params = {}|
        body = original.call(path, params)
        body["organisms"]&.each { |organism| organism["name"] = "Não catalogado" } if path.match?(%r{/test_types/\d})
        body
      end
    end

    it "reports it instead of guessing at which one was meant" do
      expect(source.test_type_organism_links).to be_empty
      expect(source.warnings).to contain_exactly(a_string_including("«Não catalogado»"))
    end
  end

  describe "credentials" do
    it "refuses to read without either a token or a login" do
      expect { described_class.token_from_env("http://mlab.example") }
        .to raise_error(described_class::Error, /MLAB_API_TOKEN/)
    end

    it "uses a token that was issued out of band" do
      ENV["MLAB_API_TOKEN"] = "token-do-import"

      expect(described_class.token_from_env("http://mlab.example")).to eq("token-do-import")
    ensure
      ENV.delete("MLAB_API_TOKEN")
    end
  end
end
