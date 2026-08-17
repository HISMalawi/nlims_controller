# frozen_string_literal: true

require "rails_helper"

RSpec.describe TestResult do
  let(:order_test) { create(:order_test) }
  let(:indicator) { create(:indicator) }

  def record(value, **options)
    described_class.record!(order_test: order_test, indicator: indicator, value: value, **options)
  end

  it "records a reading with its unit and who took it" do
    result = record("12.4", unit: "g/dL", recorded_by: "tec.mabjaia")

    expect(result).to be_current
    expect(result.value).to eq("12.4")
    expect(result.uuid).to be_present
  end

  it "needs a value and a time it was taken" do
    result = build(:test_result, value: nil, recorded_at: nil)

    expect(result).not_to be_valid
    expect(result.errors.attribute_names).to include(:value, :recorded_at)
  end

  describe "a correction" do
    # The national node may already have distributed the wrong value. An
    # overwrite would leave the two nodes disagreeing with nothing to say which
    # reading came second.
    it "writes a new row and points the old one at it" do
      wrong = record("12.4")
      right = record("14.2")

      expect(described_class.where(order_test: order_test, indicator: indicator).count).to eq(2)
      expect(wrong.reload.replaced_by_uuid).to eq(right.uuid)
      expect(wrong).to be_replaced
      expect(right).to be_current
    end

    it "leaves exactly one current reading per indicator" do
      3.times { |n| record("1#{n}.0") }

      expect(order_test.current_results.count).to eq(1)
      expect(order_test.current_results.first.value).to eq("12.0")
    end

    it "can be followed forwards" do
      wrong = record("12.4")
      right = record("14.2")

      expect(wrong.reload.replaced_by).to eq(right)
      expect(right.replaced_by).to be_nil
    end

    it "does not touch the readings of other indicators" do
      other = record("12.4")
      described_class.record!(order_test: order_test, indicator: create(:indicator), value: "5.1")

      expect(other.reload).to be_current
      expect(order_test.current_results.count).to eq(2)
    end
  end

  describe "immutability" do
    it "refuses to have a recorded reading edited" do
      result = record("12.4")

      expect(result.update(value: "14.2")).to be(false)
      expect(result.errors.full_messages.to_sentence).to include("cannot be edited")
      expect(result.reload.value).to eq("12.4")
    end

    it "refuses to have the indicator it was recorded against moved" do
      result = record("12.4")

      expect(result.update(indicator: create(:indicator))).to be(false)
    end

    # The one change a recorded result is allowed: being marked as superseded.
    it "still accepts being marked as replaced" do
      result = record("12.4")

      expect(result.update(replaced_by_uuid: SecureRandom.uuid)).to be(true)
    end
  end
end
