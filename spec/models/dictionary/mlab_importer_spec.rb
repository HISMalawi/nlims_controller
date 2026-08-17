# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::MlabImporter do
  let(:source) { MlabFixtureSource.load }

  def import(from = source)
    described_class.new(source: from).call
  end

  describe "a first import" do
    it "loads every entity type" do
      import

      expect(Department.count).to eq(2)
      expect(SpecimenType.count).to eq(3)
      expect(Drug.count).to eq(2)
      expect(Organism.count).to eq(2)
      expect(TestType.count).to eq(3)
      expect(TestPanel.count).to eq(2)
    end

    it "leaves everything as a draft, so nothing reaches a local node yet" do
      import

      expect(Dictionary.models.sum { |model| model.published.count }).to eq(0)
      expect(Dictionary.changes_since(0)).to be_empty
    end

    it "allocates our own national codes rather than carrying mLab ids" do
      import

      expect(TestType.find_by(name: "Hemograma completo").national_code).to match(/\AMOZ-TT-\d{4}\z/)
    end

    it "keeps the mLab id as an external mapping" do
      import

      test_type = TestType.find_by(name: "Hemograma completo")
      expect(ExternalMapping.resolve(system: "mlab", entity_type: "test_types", external_code: "1"))
        .to eq(test_type.uuid)
    end

    it "records the creation against the import in the publication history" do
      import

      change = DictionaryStatusChange.find_by(entity_uuid: TestType.find_by(name: "Urina II").uuid)
      expect(change.from_status).to be_nil
      expect(change.to_status).to eq("draft")
      expect(change.actor).to eq(described_class::ACTOR)
    end

    it "skips a row with no name instead of inventing one" do
      result = import

      expect(Indicator.count).to eq(4)
      expect(result.skipped).to contain_exactly(
        { entity_type: "indicators", external_code: 4, reason: "sem nome" }
      )
    end
  end

  describe "translation" do
    before { import }

    it "maps mLab's indicator types to value types" do
      expect(Indicator.find_by(name: "Hemoglobina", value_type: "Numeric")).to be_present
      expect(Indicator.find_by(name: "Cultura").value_type).to eq("Free Text")
    end

    it "maps the spelled-out sexes to the letters the rest of the system uses" do
      expect(TestType.find_by(name: "Cultura de sangue").performed_on_sex).to eq("F")
      expect(TestType.find_by(name: "Hemograma completo").performed_on_sex).to eq("Both")
    end

    it "carries the turnaround time and the section" do
      test_type = TestType.find_by(name: "Hemograma completo")

      expect(test_type.target_tat).to eq("4 horas")
      expect(test_type.department.name).to eq("Bioquímica")
    end

    it "keeps the section code as the ministry code" do
      expect(Department.find_by(name: "Bioquímica").moh_code).to eq("BIO")
    end
  end

  describe "links" do
    before { import }

    it "attaches specimens, indicators and organisms to their tests" do
      test_type = TestType.find_by(name: "Hemograma completo")

      expect(test_type.specimen_types.map(&:name)).to eq([ "Sangue total" ])
      expect(test_type.indicators.map(&:name)).to contain_exactly("Hemoglobina", "Leucócitos")
      expect(TestType.find_by(name: "Cultura de sangue").organisms.map(&:name)).to eq([ "Escherichia coli" ])
    end

    it "attaches drugs to organisms and tests to panels" do
      expect(Organism.find_by(name: "Escherichia coli").drugs.map(&:name)).to eq([ "Amoxicilina" ])
      expect(TestPanel.find_by(name: "Painel básico").test_types.count).to eq(2)
    end

    it "loads the ranges of an indicator" do
      expect(Indicator.find_by(name: "Hemoglobina", value_type: "Numeric").indicator_ranges.count).to eq(3)
    end
  end

  describe "a second import" do
    before { import }

    it "creates nothing and changes nothing" do
      result = import

      expect(result.entities.values.sum { |counts| counts[:created] }).to eq(0)
      expect(result.entities.values.sum { |counts| counts[:updated] }).to eq(0)
      expect(Dictionary.models.sum(&:count)).to eq(18)
    end

    # The cursor is what every local node walks. An import that moved it without
    # anything having changed would have every node in the country re-download
    # the dictionary for nothing.
    it "does not move the revision cursor" do
      expect { import }.not_to change(Dictionary, :cursor)
    end

    it "does not pile up duplicate links or ranges" do
      before_counts = [ TestTypeIndicator.count, IndicatorRange.count, OrganismDrug.count,
                        TestTypeSpecimenType.count, TestPanelTestType.count ]

      import

      expect([ TestTypeIndicator.count, IndicatorRange.count, OrganismDrug.count,
               TestTypeSpecimenType.count, TestPanelTestType.count ]).to eq(before_counts)
    end

    it "does not add to the publication history" do
      expect { import }.not_to change(DictionaryStatusChange, :count)
    end
  end

  describe "when the source has changed" do
    before { import }

    it "updates an entry that was renamed upstream" do
      import(source.change(:test_types, 1, name: "Hemograma"))

      expect(TestType.find_by(name: "Hemograma")).to be_present
      expect(TestType.count).to eq(3)
    end

    it "moves the cursor only for what actually changed" do
      cursor = Dictionary.cursor

      import(source.change(:test_types, 1, name: "Hemograma"))

      expect(Dictionary.changes_since(cursor)).to be_empty # still a draft
      expect(TestType.find_by(name: "Hemograma").revision).to be > cursor
    end

    it "removes a link that has gone away upstream" do
      import(source.replace(:test_type_indicator_links, [ { test_type_id: 1, indicator_id: 1 } ]))

      expect(TestType.find_by(name: "Hemograma completo").indicators.map(&:name)).to eq([ "Hemoglobina" ])
    end

    it "moves a test type whose links changed, so the delta carries them" do
      test_type = TestType.find_by(name: "Hemograma completo")
      test_type.activate!(actor: "spec")
      cursor = Dictionary.cursor

      import(source.replace(:test_type_indicator_links, [ { test_type_id: 1, indicator_id: 1 } ]))

      expect(Dictionary.changes_since(cursor).map(&:last)).to include(test_type.reload)
    end

    # It cannot simply be deleted: a local node may already hold it, and only a
    # retirement travels down the delta.
    it "retires an entry that has disappeared upstream" do
      result = import(source.without(:test_types, 2))

      entry = TestType.find_by(name: "Urina II")
      expect(entry).to be_retired
      expect(entry.deleted_at).to be_present
      expect(result.retired["test_types"]).to eq(1)
    end

    it "records the retirement with a reason" do
      import(source.without(:test_types, 2))

      change = DictionaryStatusChange.for_entity(TestType.find_by(name: "Urina II").uuid).last
      expect(change.to_status).to eq("retired")
      expect(change.reason).to include("já não existe")
    end

    it "leaves an entry retired without churning it on later runs" do
      import(source.without(:test_types, 2))
      revision = TestType.find_by(name: "Urina II").revision

      import(source.without(:test_types, 2))

      expect(TestType.find_by(name: "Urina II").revision).to eq(revision)
    end
  end
end
