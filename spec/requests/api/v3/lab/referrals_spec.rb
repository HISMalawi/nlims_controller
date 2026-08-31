# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Referrals between laboratories", mode: :local, type: :request do
  let(:api_client) { create(:api_client, :sislab, facility_code: "HCM", lab_code: "HCM-LAB") }
  let(:token) { issue_key(api_client: api_client, scopes: %w[referrals:write]).last }

  # The national register, as this node holds it. A referral is addressed to a
  # laboratory code and nothing else: the health facility and the name that goes
  # in the history are read from here.
  before do
    create(:lab, national_code: "MAP-LAB-CENTRAL", name: "Laboratório Central de Maputo", facility_code: "MAP")
  end

  # A sample that reached the bench and turned out to need a laboratory that
  # can run the test.
  def in_progress_order
    @in_progress_order ||= create(:order, receiving_lab_code: "HCM-LAB").tap do |order|
      order.claim!(lab_code: "HCM-LAB")
      order.transition_to!(Order::SPECIMEN_COLLECTED)
      order.transition_to!(Order::IN_PROGRESS)
    end
  end

  def send_json(method, path, body, bearer: token)
    process(method, path,
            params: body.to_json,
            headers: { "Authorization" => "Bearer #{bearer}", "Content-Type" => "application/json" })
  end

  describe "POST /api/v3/lab/referrals" do
    def refer(body = {}, bearer: token)
      send_json(:post, "/api/v3/lab/referrals",
                { tracking_number: in_progress_order.tracking_number, to_lab_code: "MAP-LAB-CENTRAL",
                  courier: "Transporte MISAU", remarks: "sem reagente" }.merge(body), bearer: bearer)
    end

    it "sends the sample on and says so" do
      refer

      expect(response).to have_http_status(:created)

      data = response.parsed_body["data"]
      expect(data["state"]).to eq(Referral::DISPATCHED)
      expect(data["to_lab_code"]).to eq("MAP-LAB-CENTRAL")
      expect(data["from_facility_code"]).to eq("HCM")
      expect(data["dispatched_at"]).to be_present
    end

    # The client sent a laboratory code and nothing else.
    it "fills in the health facility from the register" do
      refer

      expect(response.parsed_body.dig("data", "to_facility_code")).to eq("MAP")
    end

    # The clinic goes on asking after the same number, whichever institution
    # ends up running the test.
    it "keeps the tracking number the sample already had" do
      refer

      expect(response.parsed_body.dig("data", "tracking_number")).to eq(in_progress_order.tracking_number)
    end

    it "moves the order out" do
      refer

      expect(in_progress_order.reload.status).to eq(Order::REFERRED_OUT)
      expect(in_progress_order.own_status_events.last.reason).to include("Laboratório Central de Maputo")
    end

    it "tells the rest of the country, carrying the whole sample" do
      refer

      event = OutboxEvent.find_by!(type: OutboxEvent::REFERRAL_DISPATCHED)
      expect(event.aggregate_uuid).to eq(in_progress_order.uuid)
      expect(event.payload.dig("referral", "to_facility_code")).to eq("MAP")
      expect(event.payload.dig("order", "tracking_number")).to eq(in_progress_order.tracking_number)
      expect(event.payload.dig("order", "patient", "name")).to be_present
    end

    it "refuses to refer a sample to the laboratory that already has it" do
      create(:lab, national_code: "HCM-LAB", facility_code: "HCM")

      refer({ to_lab_code: "HCM-LAB" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(in_progress_order.reload.status).to eq(Order::IN_PROGRESS)
    end

    it "refuses a referral with nowhere to go" do
      refer({ to_lab_code: nil })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "field")).to eq("to_lab_code")
    end

    # The register is the list of laboratories in the country. A code that is
    # not in it is a typo, and a parcel addressed to a typo never arrives.
    it "refuses a laboratory the register does not carry" do
      refer({ to_lab_code: "MAP-LAB-INVENTADO" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "field")).to eq("to_lab_code")
      expect(Referral.count).to be_zero
    end

    it "refuses to refer a sample that has not reached the bench" do
      order = create(:order, receiving_lab_code: "HCM-LAB")

      refer({ tracking_number: order.tracking_number })

      expect(response).to have_http_status(:unprocessable_content)
      expect(order.reload.status).to eq(Order::REQUESTED)
      expect(Referral.count).to be_zero
    end

    it "answers 403 for a key that may not refer" do
      reader = issue_key(api_client: api_client, scopes: %w[orders:read])

      refer({}, bearer: reader.last)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v3/lab/referrals/{uuid}" do
    # The receiving side: a laboratory that has been sent a sample and is
    # saying what happened to the parcel.
    let(:receiving_client) { create(:api_client, :sislab, facility_code: "MAP", lab_code: "MAP-LAB-CENTRAL") }
    let(:receiving_token) { issue_key(api_client: receiving_client, scopes: %w[referrals:write]).last }

    # As the receiving node holds it: the order arrived as a copy, already in
    # referred_in, and the referral came with it rather than being dispatched
    # from here.
    def referred_order
      @referred_order ||= create(:order, sending_facility_code: "HCM",
                                         receiving_lab_code: "MAP-LAB-CENTRAL",
                                         status: Order::REFERRED_IN)
    end

    def referral
      @referral ||= Referral.create!(
        order: referred_order, tracking_number: referred_order.tracking_number,
        from_facility_code: "HCM", from_lab_code: "HCM-LAB",
        to_facility_code: "MAP", to_lab_code: "MAP-LAB-CENTRAL",
        dispatched_at: 2.hours.ago, replicated: true
      )
    end

    def settle(body, bearer: receiving_token)
      send_json(:patch, "/api/v3/lab/referrals/#{referral.uuid}", body, bearer: bearer)
    end

    it "records that the sample arrived, and takes the work on" do
      settle({ state: Referral::RECEIVED, remarks: "chegou às 14h" })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "state")).to eq(Referral::RECEIVED)
      expect(referral.reload.received_at).to be_present
      expect(referred_order.reload.status).to eq(Order::ACCEPTED)
    end

    # The number nobody in the country can currently produce.
    it "makes the transport time measurable" do
      settle({ state: Referral::RECEIVED })

      expect(referral.reload.transport_time).to be >= 0
    end

    it "records a refusal with the reason, and refuses the sample" do
      reason = create(:rejection_reason, name: "Amostra hemolisada")

      settle({ state: Referral::REJECTED, reason: { national_code: reason.national_code },
               remarks: "chegou quente" })

      expect(response).to have_http_status(:ok)
      expect(referral.reload.state).to eq(Referral::REJECTED)
      expect(referral.rejection_reason).to eq(reason)
      expect(referred_order.reload.status).to eq(Order::REJECTED)
      expect(referred_order.rejection_reason).to eq(reason)
    end

    it "tells the rest of the country either way" do
      settle({ state: Referral::RECEIVED })

      expect(OutboxEvent.exists?(type: OutboxEvent::REFERRAL_RECEIVED)).to be(true)
    end

    it "answers 409 when the parcel has already been settled" do
      settle({ state: Referral::RECEIVED })
      settle({ state: Referral::RECEIVED })

      expect(response).to have_http_status(:conflict)
    end

    it "refuses a state that is not one of the two things that can happen" do
      settle({ state: "perdida" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "field")).to eq("state")
    end

    # The list of rejection reasons is not consolidated either, and a parcel
    # refused for a reason nobody has catalogued is still a refused parcel.
    it "records a refusal for a reason the dictionary does not carry" do
      settle({ state: Referral::REJECTED, reason: "Tubo partido em trânsito" })

      expect(response).to have_http_status(:ok)
      expect(referral.reload.state).to eq(Referral::REJECTED)
      expect(referral.rejection_reason).to be_nil
      expect(referral.rejection_reason_label).to eq("Tubo partido em trânsito")
    end

    it "refuses a rejection that gives no reason at all" do
      settle({ state: Referral::REJECTED })

      expect(response).to have_http_status(:unprocessable_content)
      expect(referral.reload).to be_dispatched
    end

    it "answers 404 for a referral this node does not have" do
      send_json(:patch, "/api/v3/lab/referrals/#{SecureRandom.uuid}", { state: Referral::RECEIVED },
                bearer: receiving_token)

      expect(response).to have_http_status(:not_found)
    end
  end
end
