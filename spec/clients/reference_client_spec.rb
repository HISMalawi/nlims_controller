# frozen_string_literal: true

require "rails_helper"

# The reference client in clients/ruby, driven against this node.
#
# This is S12's acceptance criterion for the client: all three profiles walked
# against a real node rather than a mock. Every call here goes through routing,
# authentication, scopes, the state machines and the database, and — because it
# arrives through ActionDispatch — is also checked against the OpenAPI contract
# on the way back. So one run proves three things agree: the client, the node,
# and the document a team integrating will be reading.
RSpec.describe SislabSyncClient, type: :request do
  # The base_url is never dialled: RackTransport puts the request straight into
  # this node's Rack stack. The sleeper is emptied so a retry costs no wall
  # clock, since what is being tested is that it retries, not that it waits.
  def profile_for(klass, token)
    klass.new(
      connection: SislabSyncClient::Connection.new(
        base_url: "http://node.test",
        api_key: token,
        transport: RackTransport.new(self),
        sleeper: ->(_seconds) { }
      )
    )
  end

  describe "every profile", mode: :local do
    let(:api_client) { create(:api_client, facility_code: "HCM") }
    let(:token) { issue_key(api_client: api_client, scopes: %w[dictionary:read]).last }
    let(:emr) { profile_for(SislabSyncClient::Emr, token) }

    it "says which node it is talking to, without needing the key to be good" do
      expect(emr.health).to include("mode" => SislabSync.mode, "node_code" => SislabSync.node_code)
    end

    it "says what the key is and what it may do" do
      me = emr.me

      expect(me.dig("client", "facility_code")).to eq("HCM")
      expect(me.dig("key", "scopes")).to eq(%w[dictionary:read])
      expect(me.dig("node", "mode")).to eq(SislabSync.mode)
    end

    it "reads the catalogue an order form is built from" do
      create(:test_type, name: "Hemograma")

      entries = emr.dictionary("test_types")

      expect(entries.map { |entry| entry["name"] }).to include("Hemograma")
    end

    it "refuses an entity the dictionary does not have, without asking the node" do
      expect { emr.dictionary("unicorns") }.to raise_error(ArgumentError, /not a dictionary entity/)
    end

    it "walks the whole dictionary on one cursor" do
      create(:test_type, name: "Hemograma")
      create(:specimen_type, name: "Sangue total")

      names = emr.dictionary_changes(since: 0).map { |entry| entry["name"] }

      expect(names).to include("Hemograma", "Sangue total")
    end
  end

  # The order the three integrations actually happen in: a clinic asks, a
  # laboratory does the work, the clinic collects the answer.
  describe "a sample from request to result", mode: :local do
    let(:emr) do
      clinic = create(:api_client, facility_code: "HCM")
      profile_for(SislabSyncClient::Emr,
                  issue_key(api_client: clinic, scopes: %w[orders:write orders:read results:read]).last)
    end
    let(:lab) { lab_profile(%w[orders:read results:write]) }

    let!(:specimen_type) { create(:specimen_type, name: "Sangue total") }
    let!(:test_type) { create(:test_type, name: "Hemograma") }
    let!(:indicator) { create(:indicator, name: "Hemoglobina", unit: "g/dL") }

    # A SISLAB key for this laboratory, with whatever it is allowed to do. Made
    # here rather than memoised because one example needs a second key with a
    # scope the others have no business holding.
    def lab_profile(scopes)
      laboratory = create(:api_client, :sislab, facility_code: "HCM", lab_code: "HCM-LAB")

      profile_for(SislabSyncClient::Lab, issue_key(api_client: laboratory, scopes: scopes).last)
    end

    def request_a_sample
      emr.create_order(
        patient: { national_id: "110100234567A", name: "Ana Macuácua", sex: "F", birthdate: "1991-04-12" },
        order: {
          receiving_lab_code: "HCM-LAB",
          priority: "routine",
          requested_by: "Dr. J. Sitoe",
          specimen_type: specimen_type.national_code
        },
        tests: [ test_type.national_code ]
      )
    end

    it "hands back a tracking number the clinic can put on the tube" do
      receipt = request_a_sample

      expect(receipt["tracking_number"]).to match(TrackingNumber::FORMAT)
      expect(receipt["status"]).to eq(Order::REQUESTED)
    end

    # A node is a health facility and holds several laboratories. A LIS says
    # which of them is submitting; a laboratory the node has never seen is
    # registered from what it says rather than refused.
    it "registers the laboratory a LIS names for the first time" do
      receipt = emr.create_order(
        lab: { code: "LAB07", name: "Laboratório de Bioquímica" },
        patient: { name: "Ana Macuácua" },
        order: { specimen_type: specimen_type.national_code },
        tests: [ test_type.national_code ]
      )

      expect(receipt["tracking_number"]).to be_present
      expect(Lab.find_by!(facility_code: "HCM", source_code: "LAB07")).to be_local
      expect(Order.find_by!(uuid: receipt["order_uuid"]).receiving_lab_code).to eq("LAB07")
    end

    # A clinician asks the unit, not a bench. The sample waits unclaimed, in
    # every laboratory's feed, until one of them takes it.
    it "leaves a sample nobody named a laboratory for to be claimed at the bench" do
      receipt = emr.create_order(
        patient: { name: "Ana Macuácua" },
        order: { specimen_type: specimen_type.national_code },
        tests: [ test_type.national_code ]
      )

      lab = lab_profile(%w[orders:read])
      claimed = lab.claim(receipt["tracking_number"], lab_code: "HCM-MICRO")

      expect(claimed["receiving_lab_code"]).to eq("HCM-MICRO")
      expect(claimed["claimed_by_lab_code"]).to eq("HCM-MICRO")
    end

    it "reaches the laboratory's queue" do
      tracking_number = request_a_sample["tracking_number"]

      queued = lab.pending_orders(since: 0).map { |order| order["tracking_number"] }

      expect(queued).to include(tracking_number)
    end

    it "goes from the bench back to the clinic" do
      tracking_number = request_a_sample["tracking_number"]

      expect(lab.claim(tracking_number)["status"]).to eq(Order::ACCEPTED)
      lab.transition(tracking_number, status: Order::SPECIMEN_COLLECTED, actor: "Téc. M. Nhaca")
      expect(lab.transition(tracking_number, status: Order::IN_PROGRESS)["status"]).to eq(Order::IN_PROGRESS)

      lab.record_results(
        tracking_number,
        final: true,
        actor: "Téc. M. Nhaca",
        results: [ { test_type: test_type.national_code, indicator: indicator.national_code,
                     value: "12.4", unit: "g/dL" } ]
      )

      # `final` finishes the tests it carries. Closing the sample is a
      # transition of its own: a laboratory may have more to add to an order
      # whose first test is done.
      expect(lab.transition(tracking_number, status: Order::COMPLETED)["status"]).to eq(Order::COMPLETED)

      order = emr.order_results(tracking_number)
      expect(order["status"]).to eq(Order::COMPLETED)

      reading = order.dig("tests", 0, "results", 0)
      expect(reading["value"]).to eq("12.4")
      expect(reading.dig("indicator", "name")).to eq("Hemoglobina")
    end

    it "arrives on the clinic's results feed with the context to file it" do
      tracking_number = request_a_sample["tracking_number"]
      complete(tracking_number)

      readings = emr.results(since: 0).to_a

      expect(readings.length).to eq(1)
      expect(readings.first["tracking_number"]).to eq(tracking_number)
      expect(readings.first.dig("patient", "national_id")).to eq("110100234567A")
    end

    it "leaves a cursor the clinic can come back with" do
      complete(request_a_sample["tracking_number"])

      feed = emr.results(since: 0)
      feed.each_page { |_readings, _cursor| nil }

      # Nothing new since where it got to, and it does not start again.
      expect(emr.results(since: feed.cursor).to_a).to be_empty
    end

    it "records that the clinic filed a reading" do
      tracking_number = request_a_sample["tracking_number"]
      complete(tracking_number)

      reading = emr.results(since: 0).first
      expect(emr.acknowledge(reading["uuid"])["acknowledged_at"]).to be_present
    end

    it "adds a test the bench ran but nobody asked for" do
      tracking_number = request_a_sample["tracking_number"]
      lab.claim(tracking_number)
      extra = create(:test_type, name: "Contagem de reticulócitos")

      order = lab.add_tests(tracking_number, tests: [ extra.national_code ], actor: "Téc. M. Nhaca")

      expect(order["tests"].map { |test| test.dig("test_type", "name") })
        .to contain_exactly("Hemograma", "Contagem de reticulócitos")
    end

    it "refuses a sample with a reason from the dictionary" do
      reason = create(:rejection_reason, name: "Amostra hemolisada")
      tracking_number = request_a_sample["tracking_number"]
      lab.claim(tracking_number)

      order = lab.reject(tracking_number, reason: reason.national_code, note: "Colher de novo")

      expect(order["status"]).to eq(Order::REJECTED)
      expect(order["history"].last["to_status"]).to eq(Order::REJECTED)
    end

    it "sends a sample on to a laboratory that can run it" do
      referrals = lab_profile(%w[orders:read results:write referrals:write])
      tracking_number = request_a_sample["tracking_number"]
      referrals.claim(tracking_number)
      referrals.transition(tracking_number, status: Order::SPECIMEN_COLLECTED)
      referrals.transition(tracking_number, status: Order::IN_PROGRESS)

      referral = referrals.dispatch_referral(
        tracking_number: tracking_number,
        to_facility_code: "MAP",
        to_lab_code: "MAP-LAB",
        courier: "Boleia do distrito"
      )

      expect(referral["state"]).to eq(Referral::DISPATCHED)
      expect(referral["to_lab_code"]).to eq("MAP-LAB")
    end

    def complete(tracking_number)
      lab.claim(tracking_number)
      lab.transition(tracking_number, status: Order::SPECIMEN_COLLECTED)
      lab.transition(tracking_number, status: Order::IN_PROGRESS)
      lab.record_results(
        tracking_number,
        final: true,
        results: [ { test_type: test_type.national_code, indicator: indicator.national_code, value: "12.4" } ]
      )
      lab.transition(tracking_number, status: Order::COMPLETED)
    end
  end

  # Every refusal the node can give arrives as its own class carrying the node's
  # code, so a caller can branch on the thing that is contractual instead of on
  # a Portuguese sentence that may be reworded next week.
  describe "when the node refuses", mode: :local do
    let(:api_client) { create(:api_client, facility_code: "HCM") }

    it "raises Unauthenticated for a key the node does not know" do
      emr = profile_for(SislabSyncClient::Emr, "sls_live_nothing")

      expect { emr.me }.to raise_error(SislabSyncClient::Unauthenticated) do |error|
        expect(error.code).to eq("unauthenticated")
      end
    end

    it "raises InsufficientScope when the key may not do it" do
      emr = profile_for(SislabSyncClient::Emr, issue_key(api_client: api_client, scopes: %w[dictionary:read]).last)

      expect { emr.order("MZ-HCM-26229-0001") }.to raise_error(SislabSyncClient::InsufficientScope)
    end

    it "raises NotFound for a tracking number this node never issued" do
      emr = profile_for(SislabSyncClient::Emr, issue_key(api_client: api_client, scopes: %w[orders:read]).last)

      expect { emr.order("MZ-HCM-26229-9999") }.to raise_error(SislabSyncClient::NotFound)
    end

    it "raises Unprocessable naming the field that was wrong" do
      emr = profile_for(SislabSyncClient::Emr, issue_key(api_client: api_client, scopes: %w[orders:write]).last)

      expect do
        emr.create_order(
          patient: { name: "Ana Macuácua" },
          order: { receiving_lab_code: "HCM-LAB" },
          tests: [ { method_of_testing: "PCR" } ]
        )
      end.to raise_error(SislabSyncClient::Unprocessable) do |error|
        expect(error.field).to eq("tests[0].test_type")
      end
    end

    # The catalogue is not consolidated, so a term the node does not carry is
    # kept as it was written rather than refused.
    it "takes an exam the node's dictionary has never heard of" do
      emr = profile_for(SislabSyncClient::Emr, issue_key(api_client: api_client, scopes: %w[orders:write]).last)

      receipt = emr.create_order(
        patient: { name: "Ana Macuácua" },
        order: { receiving_lab_code: "HCM-LAB" },
        tests: [ "Ferritina sérica" ]
      )

      expect(receipt["tracking_number"]).to be_present
      expect(Order.find_by!(uuid: receipt["order_uuid"]).order_tests.sole.test_type_label)
        .to eq("Ferritina sérica")
    end

    it "raises Conflict when a second laboratory wants a sample that is taken" do
      laboratory = create(:api_client, :sislab, facility_code: "HCM", lab_code: "HCM-LAB")
      lab = profile_for(SislabSyncClient::Lab,
                        issue_key(api_client: laboratory, scopes: %w[orders:read]).last)
      order = create(:order, receiving_lab_code: "HCM-LAB")

      lab.claim(order.tracking_number)

      expect { lab.claim(order.tracking_number) }.to raise_error(SislabSyncClient::Conflict)
    end
  end

  # Retrying a create is only safe because the node recognises the key and
  # replays its first answer. Without it, a dropped connection means a second
  # sample nobody drew.
  describe "idempotency", mode: :local do
    let(:api_client) { create(:api_client, facility_code: "HCM") }
    let(:emr) { profile_for(SislabSyncClient::Emr, issue_key(api_client: api_client, scopes: %w[orders:write]).last) }
    let!(:test_type) { create(:test_type, name: "Hemograma") }

    def create_with(key)
      emr.create_order(
        patient: { national_id: "110100234567A", name: "Ana Macuácua" },
        order: { receiving_lab_code: "HCM-LAB" },
        tests: [ test_type.national_code ],
        idempotency_key: key
      )
    end

    it "creates one order however many times the same key arrives" do
      key = SecureRandom.uuid

      expect { 3.times { create_with(key) } }.to change(Order, :count).by(1)
    end

    it "replays the first answer rather than inventing a second sample" do
      key = SecureRandom.uuid

      first = create_with(key)
      replayed = create_with(key)

      expect(replayed["tracking_number"]).to eq(first["tracking_number"])
    end

    it "generates a key when the caller does not, so a plain call is still safe" do
      expect(create_with(nil)["tracking_number"]).to be_present
    end
  end

  describe "the node profile", mode: :national do
    let(:api_client) { create(:api_client, :node, facility_code: "HCM") }
    let(:node) do
      profile_for(SislabSyncClient::Node,
                  issue_key(api_client: api_client, scopes: %w[sync:push sync:pull]).last)
    end

    let!(:specimen_type) { create(:specimen_type, name: "Sangue total") }
    let(:order_uuid) { SecureRandom.uuid }

    it "reports in, and is told how far the national dictionary has moved" do
      answer = node.heartbeat(node_code: "HCM", name: "Hospital Central de Maputo",
                              version: SislabSync.version, outbox_pending: 4, outbox_failing: 1)

      expect(answer["node_code"]).to eq("HCM")
      expect(answer["last_seen_at"]).to be_present
      expect(answer["dictionary_cursor"]).to eq(Dictionary.cursor)
    end

    it "hands over what happened at the laboratory" do
      answer = node.push_events(node_code: "HCM", events: [ order_created ])

      expect(answer["accepted"].length).to eq(1)
      expect(answer["rejected"]).to be_empty
      expect(Order.find_by(uuid: order_uuid)).to be_present
    end

    it "names what it could not apply, rather than failing the whole batch" do
      malformed = order_created.tap { |event| event[:payload][:order] = nil }

      answer = node.push_events(node_code: "HCM", events: [ malformed ])

      expect(answer["accepted"]).to be_empty
      expect(answer["rejected"].first["event_uuid"]).to eq(malformed[:event_uuid])
    end

    # A term the national catalogue has not reached is not a reason to refuse
    # a laboratory's work: it is kept as it arrived, and linked later.
    it "takes an event naming a term the capital does not carry" do
      unknown = order_created(specimen_type: { national_code: "NAO-EXISTE", name: "Aspirado medular" })

      answer = node.push_events(node_code: "HCM", events: [ unknown ])

      expect(answer["rejected"]).to be_empty
      expect(Order.find_by!(uuid: order_uuid).specimen_type_label).to eq("Aspirado medular")
    end

    it "refuses to send a batch bigger than the node will take, before sending it" do
      batch = Array.new(SislabSyncClient::Node::MAX_EVENTS + 1) { order_created }

      expect { node.push_events(node_code: "HCM", events: batch) }
        .to raise_error(ArgumentError, /at most 500 events/)
    end

    it "reads back what the capital is holding for a node" do
      expect(node.inbound(node_code: "HCM", since: 0).to_a).to eq([])
    end

    def order_created(**overrides)
      {
        event_uuid: SecureRandom.uuid,
        aggregate_uuid: order_uuid,
        sequence: 1,
        type: "order.created",
        occurred_at: Time.current.iso8601,
        payload: {
          tracking_number: "MZ-HCM-26229-0001", to_status: "requested", actor: "emr-hcm",
          order: {
            uuid: order_uuid, tracking_number: "MZ-HCM-26229-0001", status: "requested",
            priority: "routine", sending_facility_code: "HCM", receiving_lab_code: "HCM-LAB",
            specimen_type: { national_code: specimen_type.national_code },
            patient: { uuid: SecureRandom.uuid, national_id: "110100234567A", name: "Ana Macuácua",
                       sex: "F", birthdate: "1991-04-12" }
          }.merge(overrides)
        }
      }
    end
  end
end
