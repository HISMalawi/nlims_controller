# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrderSerializer do
  let(:order) { create(:order) }

  it "reports the state of every test without the readings" do
    create_list(:order_test, 2, order: order)

    json = described_class.call(order)

    expect(json[:tests].length).to eq(2)
    expect(json[:tests].first).not_to have_key(:results)
    expect(json).not_to have_key(:history)
  end

  it "ships the readings only when asked, oldest first, corrections included" do
    order_test = create(:order_test, order: order)
    indicator = create(:indicator)
    TestResult.record!(order_test: order_test, indicator: indicator, value: "12.4",
                       recorded_at: 2.hours.ago)
    TestResult.record!(order_test: order_test, indicator: indicator, value: "14.2",
                       recorded_at: 1.hour.ago)

    results = described_class.call(order, results: true).dig(:tests, 0, :results)

    expect(results.map { |result| result[:value] }).to eq([ "12.4", "14.2" ])
    expect(results.first[:replaced_by_uuid]).to eq(results.last[:uuid])
    expect(results.last[:replaced_by_uuid]).to be_nil
  end

  it "renders an order with nothing on it yet" do
    order = create(:order, specimen_type: nil, collected_at: nil)

    json = described_class.call(order)

    expect(json[:specimen_type]).to be_nil
    expect(json[:collected_at]).to be_nil
    expect(json[:tests]).to be_empty
  end

  # Times are the one field two systems in different time zones will disagree
  # about, so they travel in the one format that carries the offset.
  it "sends times as ISO 8601" do
    json = described_class.call(create(:order, collected_at: Time.zone.local(2026, 9, 14, 8, 20)))

    expect(json[:collected_at]).to eq("2026-09-14T08:20:00+02:00")
  end
end
