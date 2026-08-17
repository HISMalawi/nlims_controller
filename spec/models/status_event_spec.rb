# frozen_string_literal: true

require "rails_helper"

RSpec.describe StatusEvent do
  let(:order) { create(:order) }

  it "names the table its subject lives in, so a reader knows what it is holding" do
    event = order.own_status_events.first

    expect(event.entity_type).to eq("orders")
    expect(event.entity_uuid).to eq(order.uuid)
    expect(event.tracking_number).to eq(order.tracking_number)
    expect(event).to be_created
  end

  describe "append-only" do
    # A history that can be edited afterwards is not a history, and the audit
    # this table replaces was edited in place by four different code paths.
    it "refuses to be rewritten" do
      event = order.own_status_events.first

      expect { event.update!(to_status: "completed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(event.reload.to_status).to eq(Order::REQUESTED)
    end

    it "refuses to be deleted" do
      event = order.own_status_events.first

      expect { event.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(described_class.exists?(event.id)).to be(true)
    end
  end

  it "reads oldest first for an entity and newest first for a dashboard" do
    order.transition_to!(Order::ACCEPTED)

    expect(described_class.for_entity(order.uuid).map(&:to_status))
      .to eq([ Order::REQUESTED, Order::ACCEPTED ])
    expect(described_class.where(entity_uuid: order.uuid).recent.first.to_status).to eq(Order::ACCEPTED)
  end
end
