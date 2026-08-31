# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrderTest do
  it "is born pending under its order's tracking number" do
    order = create(:order)
    order_test = create(:order_test, order: order)

    expect(order_test.status).to eq(described_class::PENDING)
    expect(order_test.tracking_number).to eq(order.tracking_number)
  end

  it "walks pending to completed" do
    order_test = create(:order_test)

    order_test.transition_to!(described_class::IN_PROGRESS)
    order_test.transition_to!(described_class::COMPLETED)

    expect(order_test.reload.status).to eq(described_class::COMPLETED)
  end

  it "rejects a transition it does not have, without writing" do
    order_test = create(:order_test)

    expect { order_test.transition_to!(described_class::COMPLETED) }
      .to raise_error(ActiveRecord::RecordInvalid, /cannot go from pending to completed/)

    expect(order_test.reload.status).to eq(described_class::PENDING)
  end

  # A correction is a new result row on a test that stays completed. Reopening
  # it would make the correction look like a second run of the same test.
  it "does not reopen once completed" do
    order_test = create(:order_test)
    order_test.transition_to!(described_class::IN_PROGRESS)
    order_test.transition_to!(described_class::COMPLETED)

    expect(order_test).to be_terminal
    expect { order_test.transition_to!(described_class::IN_PROGRESS) }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  # Three tests on one sample are three independent stories: one running, one
  # rejected for want of sample, one still waiting.
  it "moves independently of the other tests on the same sample" do
    order = create(:order)
    running, rejected, waiting = create_list(:order_test, 3, order: order)

    running.transition_to!(described_class::IN_PROGRESS)
    rejected.transition_to!(described_class::REJECTED, reason: "amostra insuficiente")

    expect(order.order_tests.map(&:status))
      .to contain_exactly(described_class::IN_PROGRESS, described_class::REJECTED, described_class::PENDING)
    expect(waiting.reload.status).to eq(described_class::PENDING)
    expect(order.reload.status).to eq(Order::REQUESTED)
  end

  it "keeps its own history, addressed by its own uuid" do
    order_test = create(:order_test)
    order_test.transition_to!(described_class::IN_PROGRESS, actor: "tec.mabjaia")

    expect(order_test.status_events.map(&:to_status))
      .to eq([ described_class::PENDING, described_class::IN_PROGRESS ])
  end
end
