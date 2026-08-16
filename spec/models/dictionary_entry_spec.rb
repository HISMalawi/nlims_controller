# frozen_string_literal: true

require "rails_helper"

RSpec.describe DictionaryEntry do
  describe "identity" do
    it "gives every entry a uuid that does not change" do
      test_type = create(:test_type)
      uuid = test_type.uuid

      test_type.update!(name: "Outro nome")

      expect(test_type.reload.uuid).to eq(uuid)
    end

    it "allocates a readable national code per entity type" do
      expect(create(:test_type).national_code).to match(/\AMOZ-TT-\d{4}\z/)
      expect(create(:specimen_type).national_code).to match(/\AMOZ-SP-\d{4}\z/)
      expect(create(:indicator).national_code).to match(/\AMOZ-TI-\d{4}\z/)
      expect(create(:department).national_code).to match(/\AMOZ-TC-\d{4}\z/)
    end

    it "numbers each entity type independently" do
      create(:test_type)
      create(:test_type)

      expect(create(:specimen_type).national_code).to end_with("-0001")
    end

    it "keeps a code that was supplied, so an import can carry its own" do
      expect(create(:test_type, national_code: "MOZ-TT-9001").national_code).to eq("MOZ-TT-9001")
    end

    it "refuses two entries of the same kind with the same code" do
      create(:test_type, national_code: "MOZ-TT-9001")

      expect { create(:test_type, national_code: "MOZ-TT-9001") }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "revisions" do
    it "numbers a new entry" do
      expect(create(:test_type).revision).to be_positive
    end

    it "moves the entry forward on every change" do
      test_type = create(:test_type)

      expect { test_type.update!(name: "Hemograma") }.to change { test_type.reload.revision }
    end

    it "does not move it when nothing actually changed" do
      test_type = create(:test_type)

      expect { test_type.save! }.not_to change { test_type.reload.revision }
    end

    it "orders entries across entity types on one sequence" do
      first = create(:specimen_type)
      second = create(:test_type)
      third = create(:indicator)

      expect([ first.revision, second.revision, third.revision ]).to eq([ first.revision, second.revision,
                                                                         third.revision ].sort.uniq)
    end

    # The delta ships a test type with its specimens inline, so a link that
    # moved without its parent would never reach a local node.
    it "moves the owner when a link is attached" do
      test_type = create(:test_type)
      specimen_type = create(:specimen_type)

      expect { test_type.specimen_types << specimen_type }.to change { test_type.reload.revision }
    end

    it "moves the owner when a link is removed" do
      test_type = create(:test_type)
      test_type.specimen_types << create(:specimen_type)

      expect { test_type.test_type_specimen_types.first.destroy! }.to change { test_type.reload.revision }
    end

    it "moves the indicator when a range is added" do
      indicator = create(:indicator)

      expect { create(:indicator_range, indicator: indicator) }.to change { indicator.reload.revision }
    end
  end

  describe "publication" do
    it "starts as a draft when nothing says otherwise" do
      expect(TestType.create!(name: "Novo")).to be_draft
    end

    it "withholds drafts from the delta" do
      create(:test_type, :draft)

      expect(TestType.changed_since(0)).to be_empty
    end

    it "publishes on activation" do
      test_type = create(:test_type, :draft)

      test_type.activate!

      expect(TestType.changed_since(0)).to include(test_type)
    end

    it "keeps a retired entry in the delta so nodes learn it is gone" do
      test_type = create(:test_type)
      test_type.retire!

      expect(TestType.changed_since(0)).to include(test_type)
      expect(test_type.deleted_at).to be_present
    end

    # Un-publishing would strand every node that already holds a copy: they
    # would keep serving it with nothing to withdraw it.
    it "refuses to send a published entry back to draft" do
      test_type = create(:test_type)

      expect { test_type.update!(status: DictionaryEntry::DRAFT) }
        .to raise_error(ActiveRecord::RecordInvalid, /retire it instead/)
    end

    it "allows a draft to stay a draft" do
      test_type = create(:test_type, :draft)

      expect { test_type.update!(name: "Ainda rascunho") }.not_to raise_error
    end
  end

  describe ".changed_since" do
    it "returns only what happened after the cursor" do
      first = create(:test_type)
      second = create(:test_type)

      expect(TestType.changed_since(first.revision)).to eq([ second ])
    end

    it "excludes the entry sitting exactly on the cursor" do
      test_type = create(:test_type)

      expect(TestType.changed_since(test_type.revision)).to be_empty
    end

    it "returns entries oldest first" do
      created = Array.new(3) { create(:test_type) }

      expect(TestType.changed_since(0).to_a).to eq(created)
    end
  end
end
