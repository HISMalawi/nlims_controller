# frozen_string_literal: true

require "rails_helper"

RSpec.describe Order do
  it "is born requested, with a tracking number it did not have to be given" do
    order = create(:order)

    expect(order.status).to eq(described_class::REQUESTED)
    expect(order.tracking_number).to match(TrackingNumber::FORMAT)
  end

  it "keeps a tracking number it was given, so a replicated order stays itself" do
    order = create(:order, tracking_number: "MZ-XAI-26229-0007")

    expect(order.tracking_number).to eq("MZ-XAI-26229-0007")
  end

  # The unit that received it is the one thing still required — that is the node
  # itself, so it is always known. The laboratory is not: a clinician asks the
  # unit for a test, and which bench runs it is settled when one of them claims
  # the sample.
  it "needs the unit that received it" do
    order = build(:order, receiving_facility_code: nil)

    expect(order).not_to be_valid
    expect(order.errors.attribute_names).to include(:receiving_facility_code)
  end

  it "takes an order no laboratory has claimed yet" do
    expect(build(:order, receiving_lab_code: nil)).to be_valid
  end

  it "takes an order raised before the register named its facility" do
    expect(build(:order, sending_facility_code: nil)).to be_valid
  end

  it "refuses a priority nobody can act on" do
    expect(build(:order, priority: "quando_puder")).not_to be_valid
  end

  describe "the state machine" do
    it "walks the lifecycle the plan draws" do
      order = create(:order)

      order.transition_to!(described_class::ACCEPTED)
      order.transition_to!(described_class::SPECIMEN_COLLECTED)
      order.transition_to!(described_class::IN_PROGRESS)
      order.transition_to!(described_class::COMPLETED)

      expect(order.reload.status).to eq(described_class::COMPLETED)
      expect(order).to be_terminal
    end

    it "rejects a transition it does not have, without writing" do
      order = create(:order)

      expect { order.transition_to!(described_class::COMPLETED) }
        .to raise_error(ActiveRecord::RecordInvalid, /cannot go from requested to completed/)

      expect(order.reload.status).to eq(described_class::REQUESTED)
    end

    # The rule has to hold for every route into the column, not only for the
    # method that was written to respect it — otherwise a bare update, an
    # import or a console session walks straight past it.
    it "rejects an illegal status set by a plain update" do
      order = create(:order)

      expect(order.update(status: described_class::IN_PROGRESS)).to be(false)
      expect(order.reload.status).to eq(described_class::REQUESTED)
    end

    it "rejects a status the machine has never heard of" do
      order = create(:order)

      expect { order.transition_to!("em_ferias") }
        .to raise_error(ActiveRecord::RecordInvalid, /is not a status this record can hold/)
    end

    it "does not run backwards" do
      order = create(:order)
      order.transition_to!(described_class::ACCEPTED)

      expect { order.transition_to!(described_class::REQUESTED) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end

    # A referred sample is finished under the tracking number it started with,
    # whichever laboratory produced the reading.
    it "completes a sample that was referred out" do
      order = create(:order)
      [ described_class::ACCEPTED, described_class::SPECIMEN_COLLECTED,
        described_class::IN_PROGRESS, described_class::REFERRED_OUT,
        described_class::COMPLETED ].each { |status| order.transition_to!(status) }

      expect(order.reload.status).to eq(described_class::COMPLETED)
    end

    it "reports what may happen next" do
      expect(create(:order).next_statuses)
        .to contain_exactly(described_class::ACCEPTED, described_class::CANCELLED)
    end
  end

  describe "the history" do
    it "records the state the order was born in" do
      order = create(:order)

      expect(order.own_status_events.map(&:to_status)).to eq([ described_class::REQUESTED ])
      expect(order.own_status_events.first.from_status).to be_nil
    end

    it "records one event per transition, with who and why" do
      order = create(:order)
      order.transition_to!(described_class::ACCEPTED, actor: "tec.mabjaia", reason: "amostra recebida")

      event = order.own_status_events.last
      expect(event.from_status).to eq(described_class::REQUESTED)
      expect(event.to_status).to eq(described_class::ACCEPTED)
      expect(event.actor).to eq("tec.mabjaia")
      expect(event.reason).to eq("amostra recebida")
    end

    it "records nothing when a save does not move the status" do
      order = create(:order)

      expect { order.update!(clinical_history: "Febre há 5 dias") }
        .not_to change { order.own_status_events.count }
    end

    # What an operator asks is "what happened to this sample", not "what
    # happened to this row" — the tests on it are part of the answer.
    it "gathers the order's transitions and its tests' under one tracking number" do
      order = create(:order)
      order_test = create(:order_test, order: order)
      order.transition_to!(described_class::ACCEPTED)
      order_test.transition_to!(OrderTest::IN_PROGRESS)

      expect(order.status_events.map { |event| [ event.entity_type, event.to_status ] })
        .to eq([
                 [ "orders", described_class::REQUESTED ],
                 [ "order_tests", OrderTest::PENDING ],
                 [ "orders", described_class::ACCEPTED ],
                 [ "order_tests", OrderTest::IN_PROGRESS ]
               ])
    end
  end

  describe "claiming" do
    # Reading the column and then writing it lets two laboratories both find it
    # empty and both claim. These need real concurrent connections, so they run
    # outside the surrounding test transaction and clean up after themselves.
    describe "when two laboratories ask at the same moment" do
      self.use_transactional_tests = false

      after do
        OutboxEvent.delete_all
        StatusEvent.delete_all
        OrderTest.delete_all
        described_class.delete_all
        Patient.delete_all
        SpecimenType.delete_all
        Sequence.where("name LIKE 'tracking:%'").delete_all
        Sequence.update_all(value: 0)
      end

      it "gives the sample to exactly one of them" do
        order = create(:order, receiving_lab_code: "HCM-LAB")

        outcomes = Array.new(3) do |n|
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              described_class.find(order.id).claim!(lab_code: "LAB-#{n}")
              :claimed
            rescue described_class::AlreadyClaimed
              :refused
            end
          end
        end.map(&:value)

        expect(outcomes.count(:claimed)).to eq(1)
        expect(outcomes.count(:refused)).to eq(2)
        expect(order.reload.claimed_by_lab_code).to match(/\ALAB-\d\z/)
      end
    end
  end

  describe "scopes" do
    it "counts as open until it reaches a state nothing leaves" do
      order = create(:order)
      expect(described_class.open).to include(order)

      order.transition_to!(described_class::CANCELLED)
      expect(described_class.open).not_to include(order)
    end
  end
end
