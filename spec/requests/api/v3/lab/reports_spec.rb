# frozen_string_literal: true

require "rails_helper"

RSpec.describe "What a laboratory publishes", mode: :local, type: :request do
  let(:api_client) { create(:api_client, :sislab, facility_code: "HCM", lab_code: "HCM-LAB") }
  let(:token) { issue_key(api_client: api_client, scopes: %w[results:write]).last }

  let(:order) { create(:order, receiving_lab_code: "HCM-LAB") }
  let(:test_type) { create(:test_type, name: "Hemograma") }

  def indicator
    @indicator ||= create(:indicator, name: "Hemoglobina")
  end

  def order_test
    @order_test ||= create(:order_test, order: order, test_type: test_type)
  end

  def send_json(method, path, body, bearer: token)
    process(method, path,
            params: body.to_json,
            headers: { "Authorization" => "Bearer #{bearer}", "Content-Type" => "application/json" })
  end

  describe "PATCH /api/v3/lab/orders/{tn}/status" do
    def patch_status(status, bearer: token, **rest)
      send_json(:patch, "/api/v3/lab/orders/#{order.tracking_number}/status",
                { status: status, **rest }, bearer: bearer)
    end

    it "moves the sample and stamps who moved it" do
      order.claim!(lab_code: "HCM-LAB")

      patch_status(Order::SPECIMEN_COLLECTED, actor: "tec.mabjaia", reason: "colhida às 08h20")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "status")).to eq(Order::SPECIMEN_COLLECTED)

      event = order.own_status_events.last
      expect(event.actor).to eq("tec.mabjaia")
      expect(event.reason).to eq("colhida às 08h20")
    end

    it "falls back to the installation when no technician is named" do
      order.claim!(lab_code: "HCM-LAB")

      patch_status(Order::SPECIMEN_COLLECTED)

      expect(order.own_status_events.last.actor).to eq(api_client.name)
    end

    it "refuses a transition the machine does not have, without writing" do
      patch_status(Order::COMPLETED)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "field")).to eq("status")
      expect(order.reload.status).to eq(Order::REQUESTED)
    end

    it "refuses to let one laboratory move another's sample" do
      other = create(:order, receiving_lab_code: "XAI-LAB")

      send_json(:patch, "/api/v3/lab/orders/#{other.tracking_number}/status", { status: Order::ACCEPTED })

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("lab_mismatch")
    end

    it "answers 403 for a key that may read but not publish" do
      reader = issue_key(api_client: api_client, scopes: %w[orders:read])

      patch_status(Order::ACCEPTED, bearer: reader.last)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("insufficient_scope")
    end
  end

  describe "POST /api/v3/lab/orders/{tn}/results" do
    def post_results(body, bearer: token)
      send_json(:post, "/api/v3/lab/orders/#{order.tracking_number}/results", body, bearer: bearer)
    end

    def reading(value, **rest)
      {
        test_type: { national_code: test_type.national_code },
        indicator: { national_code: indicator.national_code },
        value: value,
        unit: "g/dL",
        recorded_by: "tec.mabjaia",
        **rest
      }
    end

    it "records a partial reading and leaves the test running" do
      order_test

      post_results({ results: [ reading("12.4") ], final: false })

      expect(response).to have_http_status(:ok)
      expect(order_test.reload.status).to eq(OrderTest::IN_PROGRESS)
      expect(order_test.current_results.sole.value).to eq("12.4")
    end

    # A reading is evidence the test is being worked on. Making the laboratory
    # send a second request to say what the first one already proved is how
    # statuses drift away from reality.
    it "starts a test that was still in the queue" do
      order_test

      expect { post_results({ results: [ reading("12.4") ] }) }
        .to change { order_test.reload.status }.from(OrderTest::PENDING).to(OrderTest::IN_PROGRESS)
    end

    it "finishes the test when the report is final" do
      order_test

      post_results({ results: [ reading("12.4") ], final: true })

      expect(order_test.reload.status).to eq(OrderTest::COMPLETED)
      expect(response.parsed_body.dig("data", "tests", 0, "results", 0, "value")).to eq("12.4")
    end

    it "treats the same indicator sent again as a correction, keeping both" do
      order_test

      post_results({ results: [ reading("12.4") ], final: true })
      post_results({ results: [ reading("14.2") ] })

      expect(order_test.reload.test_results.count).to eq(2)
      expect(order_test.current_results.sole.value).to eq("14.2")
    end

    it "records the technician the laboratory named" do
      order_test

      post_results({ results: [ reading("12.4") ] })

      expect(order_test.reload.current_results.sole.recorded_by).to eq("tec.mabjaia")
    end

    it "refuses a test that is not on this sample, by name" do
      order_test
      other = create(:test_type, name: "Creatinina")

      post_results({ results: [ reading("12.4").merge(test_type: { national_code: other.national_code }) ] })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "message")).to include(other.national_code)
      expect(response.parsed_body.dig("errors", 0, "field")).to eq("results[0].test_type")
    end

    it "refuses an indicator the dictionary does not have" do
      order_test

      post_results({ results: [ reading("12.4").merge(indicator: { national_code: "MOZ-TI-9999" }) ] })

      expect(response.parsed_body.dig("errors", 0, "field")).to eq("results[0].indicator")
    end

    # One bad row and none of them are stored: half a report is worse to read
    # than none, because it looks complete.
    it "stores nothing when one reading in the batch is refused" do
      order_test

      expect do
        post_results({ results: [ reading("12.4"),
                                  reading("5.1").merge(indicator: { national_code: "MOZ-TI-9999" }) ] })
      end.not_to change(TestResult, :count)
    end

    it "refuses an empty report" do
      post_results({ results: [] })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "field")).to eq("results")
    end
  end

  describe "POST /api/v3/lab/orders/{tn}/reject" do
    let(:reason) { create(:rejection_reason, name: "Amostra hemolisada") }

    def post_rejection(body = { reason: { national_code: reason.national_code } }, bearer: token)
      send_json(:post, "/api/v3/lab/orders/#{order.tracking_number}/reject", body, bearer: bearer)
    end

    it "rejects the sample with a reason from the dictionary" do
      order.claim!(lab_code: "HCM-LAB")

      post_rejection

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "status")).to eq(Order::REJECTED)
      expect(order.reload.rejection_reason).to eq(reason)
    end

    it "keeps the reason and the note in the history" do
      order.claim!(lab_code: "HCM-LAB")

      post_rejection({ reason: { national_code: reason.national_code }, note: "recebida 6h depois" })

      event = order.own_status_events.last
      expect(event.reason).to include("Amostra hemolisada")
      expect(event.reason).to include("recebida 6h depois")
    end

    # A queue of work against a tube that has been thrown away is worse than no
    # queue at all.
    it "rejects every test still standing on the sample" do
      order.claim!(lab_code: "HCM-LAB")
      running = create(:order_test, order: order)
      running.transition_to!(OrderTest::IN_PROGRESS)
      waiting = create(:order_test, order: order)

      post_rejection

      expect(running.reload.status).to eq(OrderTest::REJECTED)
      expect(waiting.reload.status).to eq(OrderTest::REJECTED)
    end

    it "leaves a test that was already finished alone" do
      order.claim!(lab_code: "HCM-LAB")
      done = create(:order_test, order: order)
      done.transition_to!(OrderTest::IN_PROGRESS)
      done.transition_to!(OrderTest::COMPLETED)

      post_rejection

      expect(done.reload.status).to eq(OrderTest::COMPLETED)
    end

    it "refuses a reason that is not in the dictionary" do
      order.claim!(lab_code: "HCM-LAB")

      post_rejection({ reason: { national_code: "MOZ-RJ-9999" } })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "field")).to eq("reason")
      expect(order.reload.status).to eq(Order::ACCEPTED)
    end

    it "refuses free text in place of a code" do
      order.claim!(lab_code: "HCM-LAB")

      post_rejection({ reason: { name: "hemolisada" } })

      expect(response).to have_http_status(:unprocessable_content)
    end

    # Rejecting is something the laboratory does with a sample in its hands, so
    # it has to have taken it first.
    it "refuses to reject a sample nobody has claimed" do
      post_rejection

      expect(response).to have_http_status(:unprocessable_content)
      expect(order.reload.status).to eq(Order::REQUESTED)
      expect(order.rejection_reason).to be_nil
    end
  end
end
