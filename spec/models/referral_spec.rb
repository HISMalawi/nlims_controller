# frozen_string_literal: true

require "rails_helper"

RSpec.describe Referral, mode: :local do
  before { create(:facility, national_code: SislabSync.facility_code, name: "Hospital Central") }

  let!(:bioquimica) { create(:lab, facility_code: SislabSync.facility_code, name: "Bioquímica") }
  let!(:microbiologia) { create(:lab, facility_code: SislabSync.facility_code, name: "Microbiologia") }
  let!(:elsewhere) { create(:lab, facility_code: "MAP", name: "Laboratório Central de Maputo") }

  def sample_in_progress(lab_code: bioquimica.national_code)
    order = create(:order, receiving_facility_code: SislabSync.facility_code, receiving_lab_code: lab_code)
    order.transition_to!(Order::ACCEPTED)
    order.transition_to!(Order::SPECIMEN_COLLECTED)
    order.transition_to!(Order::IN_PROGRESS)
    order
  end

  # Two laboratories of the same unit share this node and this database. There
  # is one order row, not two, so there is no status to move: the sample has not
  # left the building, and what changes is whose work it is.
  describe "between two laboratories of the same unit" do
    it "leaves the sample in progress rather than sending it away" do
      order = sample_in_progress

      described_class.dispatch!(order: order, to_lab_code: microbiologia.national_code)

      expect(order.reload.status).to eq(Order::IN_PROGRESS)
      expect(described_class.sole).to be_internal
    end

    it "hands the work to the other bench when it is received" do
      order = sample_in_progress
      referral = described_class.dispatch!(order: order, to_lab_code: microbiologia.national_code)

      referral.receive!(actor: "tec.chissano")

      expect(order.reload.receiving_lab_code).to eq(microbiologia.national_code)
      expect(order.claimed_by_lab_code).to eq(microbiologia.national_code)
    end

    # The capital keeps the history of every sample, and a handover is part of
    # it. What it does not do is route the parcel back to the unit it never left.
    it "still tells the capital it happened" do
      order = sample_in_progress

      expect { described_class.dispatch!(order: order, to_lab_code: microbiologia.national_code) }
        .to change { OutboxEvent.where(type: OutboxEvent::REFERRAL_DISPATCHED).count }.by(1)
    end

    # Otherwise the capital would go on naming the bench that first took the
    # sample as the one that ran it. There is no second copy of the order to
    # send, so the fact travels on the referral it belongs to.
    it "carries the handover to the capital on the referral itself" do
      order = sample_in_progress
      referral = described_class.dispatch!(order: order, to_lab_code: microbiologia.national_code)
      referral.receive!(actor: "tec.chissano")

      event = OutboxEvent.where(type: OutboxEvent::REFERRAL_RECEIVED).last
      expect(event.payload.dig("referral", "to_lab_code")).to eq(microbiologia.national_code)
      expect(event.payload.dig("referral", "to_facility_code")).to eq(SislabSync.facility_code)
    end

    # A laboratory the capital has not named yet is a working laboratory, and
    # the bench next door cannot be told to wait for the capital before handing
    # it a sample.
    it "accepts a laboratory this node registered itself" do
      Lab.register_local!(source_code: "LAB09", facility_code: SislabSync.facility_code,
                                  name: "Parasitologia")
      order = sample_in_progress

      referral = described_class.dispatch!(order: order, to_lab_code: "LAB09")

      expect(referral.to_lab_code).to eq("LAB09")
      expect(referral).to be_internal
      expect(order.reload.status).to eq(Order::IN_PROGRESS)
    end
  end

  describe "to another unit" do
    it "sends the sample away" do
      order = sample_in_progress

      described_class.dispatch!(order: order, to_lab_code: elsewhere.national_code)

      expect(order.reload.status).to eq(Order::REFERRED_OUT)
      expect(described_class.sole).not_to be_internal
      expect(described_class.sole.to_facility_code).to eq("MAP")
    end

    it "refuses a destination the register does not carry" do
      order = sample_in_progress

      expect { described_class.dispatch!(order: order, to_lab_code: "NAO-EXISTE") }
        .to raise_error(InvalidRequest, /não consta do registo/)
    end

    it "names the unit on the parcel, so the receiving node can recognise it" do
      order = sample_in_progress

      described_class.dispatch!(order: order, to_lab_code: elsewhere.national_code)

      expect(described_class.sole.to_facility_code).to eq(elsewhere.facility_code)
    end
  end

  # A node whose register has never arrived can still refer — it is asked for
  # the unit itself, rather than blamed for something missing at this end. What
  # it cannot do is refer to nowhere: a parcel with no unit on it travels and
  # arrives and cannot be taken in at the other end, which is worse than being
  # told to name the destination.
  describe "on a node whose register is still empty" do
    before { Lab.delete_all }

    it "refuses a destination it cannot place, naming what is missing" do
      order = sample_in_progress(lab_code: "HCM-LAB")

      expect { described_class.dispatch!(order: order, to_lab_code: "MAP-LAB-CENTRAL") }
        .to raise_error(InvalidRequest, /to_facility_code/)
    end

    it "takes the unit from the client when the register cannot supply it" do
      order = sample_in_progress(lab_code: "HCM-LAB")

      referral = described_class.dispatch!(order: order, to_lab_code: "MAP-LAB-CENTRAL",
                                                         to_facility_code: "MAP")

      expect(referral.to_facility_code).to eq("MAP")
      expect(referral.to_lab_code).to eq("MAP-LAB-CENTRAL")
      expect(order.reload.status).to eq(Order::REFERRED_OUT)
    end

    # The register is the authority when it has an answer; the client is only
    # filling a gap. Otherwise a client could address a parcel to a unit the
    # laboratory does not belong to.
    it "prefers the register over what the client says" do
      lab = create(:lab, facility_code: "MAP", national_code: "MAP-LAB-CENTRAL")
      order = sample_in_progress

      referral = described_class.dispatch!(order: order, to_lab_code: lab.national_code,
                                                         to_facility_code: "INVENTADA")

      expect(referral.to_facility_code).to eq("MAP")
    end
  end
end
