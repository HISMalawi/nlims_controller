# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ecrã de amostras referidas", type: :request do
  before { sign_in_as }

  # Collected at this node, whatever this node is called in the run, so that
  # "sent from here" means what it says without the spec depending on the
  # facility code the suite happens to have been started with.
  def dispatch_referral(to_facility: "HPM", to_lab: "HPM-LAB")
    order = create(:order, sending_facility_code: SislabSync.node_code)
    order.transition_to!(Order::ACCEPTED)
    order.transition_to!(Order::SPECIMEN_COLLECTED)
    order.transition_to!(Order::IN_PROGRESS)

    Referral.dispatch!(order: order, to_facility_code: to_facility, to_lab_code: to_lab)
  end

  it "lista as amostras em trânsito e há quanto tempo esperam" do
    referral = travel_to(6.hours.ago) { dispatch_referral }

    get referrals_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(referral.tracking_number)
    expect(response.body).to include("em trânsito há")
  end

  it "mostra o tempo de transporte de uma amostra que chegou" do
    referral = travel_to(4.hours.ago) { dispatch_referral }
    referral.order.update_column(:status, Order::REFERRED_IN)
    referral.receive!

    get referrals_path

    expect(referral.reload.transport_time).to be_within(60).of(4.hours)
    expect(response.body).to include("Tempo médio de transporte")
    expect(response.body).to include("4 horas")
  end

  it "filtra por estado" do
    outstanding = dispatch_referral

    get referrals_path, params: { state: Referral::RECEIVED }

    expect(response.body).not_to include(outstanding.tracking_number)
  end

  it "separa as que saíram daqui das que entraram", mode: :local do
    outbound = dispatch_referral

    get referrals_path, params: { direction: "in" }
    expect(response.body).not_to include(outbound.tracking_number)

    get referrals_path, params: { direction: "out" }
    expect(response.body).to include(outbound.tracking_number)
  end
end
