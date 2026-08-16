# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sequence do
  describe ".next!" do
    it "hands out strictly increasing numbers" do
      numbers = described_class.transaction { Array.new(5) { described_class.next_revision! } }

      expect(numbers).to eq(numbers.sort.uniq)
    end

    it "keeps separate counters apart" do
      described_class.transaction do
        described_class.next!("national_code:TT")
        described_class.next!("national_code:TT")

        expect(described_class.next!("national_code:SP")).to eq(1)
      end
    end

    it "creates a counter it has not seen before" do
      described_class.transaction do
        expect(described_class.next!("national_code:ZZ")).to eq(1)
      end
    end

    # The refusal to run outside a transaction is covered in the cursor spec:
    # here the surrounding test transaction is always open, so the guard has
    # nothing to catch.
  end

  describe ".current" do
    it "reports the last number handed out" do
      described_class.transaction { described_class.next_revision! }

      expect(described_class.current(described_class::DICTIONARY_REVISION))
        .to eq(described_class.where(name: described_class::DICTIONARY_REVISION).pick(:value))
    end

    it "is zero for a counter that has never been used" do
      expect(described_class.current("national_code:QQ")).to eq(0)
    end
  end
end
