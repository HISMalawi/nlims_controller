# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictionary::Applier do
  # Serialise a dictionary, wipe it, apply the payload back: the same round trip
  # a local node makes on its first sync, minus the network.
  def wipe_dictionary!
    DictionaryLinkDeferral.delete_all
    [ TestTypeSpecimenType, TestTypeIndicator, TestTypeOrganism, TestPanelTestType,
      OrganismDrug, IndicatorRange ].each(&:delete_all)
    # Reverse order: a test type points at a section, so the sections have to go last.
    Dictionary.models.reverse.each(&:delete_all)
    DictionaryStatusChange.delete_all
  end

  def feed(limit: Dictionary::DEFAULT_LIMIT, cursor: 0)
    Dictionary.delta(cursor, limit: limit)
  end

  def build_dictionary!
    Dictionary::MlabImporter.new(source: MlabFixtureSource.load).call
    Dictionary::Promotion.new(actor: "spec").call
  end

  describe "a first sync onto an empty node" do
    # Captures the payload and a snapshot of what it should rebuild to, then
    # empties the dictionary — the state a node is in before its first sync.
    let!(:sync) do
      build_dictionary!
      captured = { entries: feed[:entries], expected: snapshot }
      wipe_dictionary!
      captured
    end

    let(:payload) { sync[:entries] }
    let(:expected) { sync[:expected] }

    def snapshot
      {
        counts: Dictionary.models.to_h { |model| [ model.entity_type, model.count ] },
        test_type: describe_test_type,
        indicator_ranges: IndicatorRange.count,
        organism_drugs: OrganismDrug.count,
        panel_size: TestPanel.find_by(name: "Painel básico").test_types.count
      }
    end

    def describe_test_type
      test_type = TestType.find_by(name: "Hemograma completo")
      {
        code: test_type.national_code,
        revision: test_type.revision,
        department: test_type.department.national_code,
        specimens: test_type.specimen_types.map(&:national_code).sort,
        indicators: test_type.indicators.map(&:national_code).sort,
        target_tat: test_type.target_tat
      }
    end

    it "rebuilds every entry" do
      described_class.new.apply(payload)

      expect(Dictionary.models.to_h { |model| [ model.entity_type, model.count ] }).to eq(expected[:counts])
    end

    it "rebuilds the links and the reference intervals" do
      described_class.new.apply(payload)

      expect(describe_test_type).to eq(expected[:test_type])
      expect(IndicatorRange.count).to eq(expected[:indicator_ranges])
      expect(OrganismDrug.count).to eq(expected[:organism_drugs])
      expect(TestPanel.find_by(name: "Painel básico").test_types.count).to eq(expected[:panel_size])
    end

    # There is one national revision space. A local node inventing its own
    # numbers would hand the SISLAB revisions the national node never issued.
    it "keeps the revisions it was given" do
      described_class.new.apply(payload)

      expect(TestType.find_by(name: "Hemograma completo").revision).to eq(expected[:test_type][:revision])
    end

    it "leaves the local counter no lower than the revisions it holds" do
      described_class.new.apply(payload)

      expect(Dictionary.cursor).to be >= Dictionary.models.map { |model| model.maximum(:revision).to_i }.max
    end

    # Over HTTP the entries are parsed JSON with string keys. Reading revision
    # off those with a symbol returned nil, and the counter silently stayed
    # behind the revisions the node was holding.
    it "reads the revision whether the keys are strings or symbols" do
      described_class.new.apply(payload.map(&:deep_stringify_keys))

      highest = payload.pluck(:revision).max
      expect(Dictionary.cursor).to be >= highest
      expect(TestType.find_by(name: "Hemograma completo").revision).to eq(expected[:test_type][:revision])
    end

    it "applies again without changing anything" do
      described_class.new.apply(payload)
      before = Dictionary.models.to_h { |model| [ model.entity_type, model.maximum(:revision) ] }

      described_class.new.apply(payload)

      expect(Dictionary.models.to_h { |model| [ model.entity_type, model.maximum(:revision) ] }).to eq(before)
      expect(IndicatorRange.count).to eq(expected[:indicator_ranges])
    end
  end

  describe "a link whose target has not arrived yet" do
    let!(:payload) do
      build_dictionary!
      entries = feed[:entries]
      wipe_dictionary!
      entries
    end

    # The feed is ordered by revision, not by creation, so on a first sync a
    # test type routinely arrives before an indicator it points at.
    it "remembers the link instead of dropping it" do
      test_types = payload.select { |entry| entry[:entity] == "test_types" }

      described_class.new.apply(test_types)

      expect(DictionaryLinkDeferral.count).to be_positive
      expect(TestType.find_by(name: "Hemograma completo").indicators).to be_empty
    end

    it "forms the link once the target turns up in a later batch" do
      applier = described_class.new
      applier.apply(payload.select { |entry| entry[:entity] == "test_types" })
      applier.apply(payload.reject { |entry| entry[:entity] == "test_types" })

      expect(TestType.find_by(name: "Hemograma completo").indicators.map(&:name))
        .to contain_exactly("Hemoglobina", "Leucócitos")
      expect(DictionaryLinkDeferral.count).to eq(0)
    end

    it "does not let resolving a deferral change the replicated revision" do
      applier = described_class.new
      applier.apply(payload.select { |entry| entry[:entity] == "test_types" })
      expected = payload.find { |entry| entry[:entity] == "test_types" && entry[:name] == "Hemograma completo" }

      applier.apply(payload.reject { |entry| entry[:entity] == "test_types" })

      expect(TestType.find_by(name: "Hemograma completo").revision).to eq(expected[:revision])
    end
  end

  describe "changes arriving later" do
    let!(:payload) do
      build_dictionary!
      entries = feed[:entries]
      wipe_dictionary!
      described_class.new.apply(entries)
      entries
    end

    it "renames an entry in place" do
      entry = payload.find { |e| e[:name] == "Hemograma completo" }
      uuid = entry[:uuid]

      described_class.new.apply([ entry.merge(name: "Hemograma", revision: entry[:revision] + 1000) ])

      expect(TestType.find_by(uuid: uuid).name).to eq("Hemograma")
      expect(TestType.where(name: "Hemograma completo")).to be_empty
    end

    # Matching on the code would break the moment a typo in a code was fixed
    # upstream: the entry would arrive as a stranger and be duplicated.
    it "matches on uuid, not on the national code" do
      entry = payload.find { |e| e[:name] == "Urina II" }

      described_class.new.apply([ entry.merge(national_code: "MOZ-TT-9999", revision: entry[:revision] + 1000) ])

      expect(TestType.where(uuid: entry[:uuid]).pick(:national_code)).to eq("MOZ-TT-9999")
      expect(TestType.count).to eq(3)
    end

    it "marks a retired entry rather than deleting it" do
      entry = payload.find { |e| e[:name] == "Urina II" }

      described_class.new.apply([
                                  entry.merge(status: "retired", revision: entry[:revision] + 1000,
                                              deleted_at: Time.current.iso8601)
                                ])

      record = TestType.find_by(uuid: entry[:uuid])
      expect(record).to be_retired
      expect(record.deleted_at).to be_present
    end

    it "removes a link that is no longer in the payload" do
      entry = payload.find { |e| e[:name] == "Hemograma completo" }

      described_class.new.apply([ entry.merge(indicators: [ entry[:indicators].first ],
                                              revision: entry[:revision] + 1000) ])

      expect(TestType.find_by(uuid: entry[:uuid]).indicators.count).to eq(1)
    end

    it "replaces an indicator's intervals when they differ" do
      entry = payload.find { |e| e[:entity] == "indicators" && e[:ranges].any? }

      described_class.new.apply([ entry.merge(ranges: [ entry[:ranges].first ],
                                              revision: entry[:revision] + 1000) ])

      expect(Indicator.find_by(uuid: entry[:uuid]).indicator_ranges.count).to eq(1)
    end

    it "leaves the intervals alone when they are unchanged" do
      entry = payload.find { |e| e[:entity] == "indicators" && e[:ranges].any? }
      ids = Indicator.find_by(uuid: entry[:uuid]).indicator_ranges.ids

      described_class.new.apply([ entry.merge(revision: entry[:revision] + 1000) ])

      expect(Indicator.find_by(uuid: entry[:uuid]).indicator_ranges.ids).to eq(ids)
    end
  end
end
