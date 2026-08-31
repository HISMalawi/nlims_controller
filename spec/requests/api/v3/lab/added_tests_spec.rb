# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v3/lab/orders/{tn}/tests", mode: :local, type: :request do
  let(:api_client) { create(:api_client, :sislab, facility_code: "HCM", lab_code: "HCM-LAB") }
  let(:token) { issue_key(api_client: api_client, scopes: %w[results:write]).last }

  let(:order) { create(:order, receiving_lab_code: "HCM-LAB") }
  let(:test_type) { create(:test_type, name: "Creatinina") }

  def add_tests(body, tracking_number: order.tracking_number, bearer: token)
    post "/api/v3/lab/orders/#{tracking_number}/tests",
         params: body.to_json,
         headers: { "Authorization" => "Bearer #{bearer}", "Content-Type" => "application/json" }
  end

  def one_test(**rest)
    { tests: [ { test_type: { national_code: test_type.national_code }, **rest } ] }
  end

  it "puts the test on the sample the clinic is already waiting on" do
    add_tests(one_test)

    expect(response).to have_http_status(:created)
    expect(order.reload.order_tests.map(&:test_type)).to eq([ test_type ])
    expect(response.parsed_body.dig("meta", "added")).to eq(1)
    expect(response.parsed_body.dig("data", "tracking_number")).to eq(order.tracking_number)
  end

  it "starts the added test in the queue like any other" do
    add_tests(one_test(method_of_testing: "Jaffé cinético"))

    added = order.reload.order_tests.sole
    expect(added.status).to eq(OrderTest::PENDING)
    expect(added.method_of_testing).to eq("Jaffé cinético")
    expect(added.status_events.sole.actor).to eq(api_client.name)
  end

  # The order row has not changed, but what it asks for has. A laboratory
  # polling the feed has to be handed the sample again or the addition reaches
  # nobody — including the other laboratory that may be watching it.
  it "moves the order so the addition reaches the feed" do
    expect { add_tests(one_test) }.to change { order.reload.revision }
  end

  # Repeating a test is how a laboratory confirms a reading it does not believe.
  it "allows a test that is already on the sample to be added again" do
    create(:order_test, order: order, test_type: test_type)

    add_tests(one_test)

    expect(order.reload.order_tests.count).to eq(2)
  end

  # The bench runs what the bench runs. A code this node's catalogue does not
  # carry is kept as it arrived rather than refused, and can be linked to the
  # dictionary later, once the national catalogue reaches it.
  it "takes a code the dictionary does not have, and keeps it" do
    add_tests({ tests: [ { test_type: { national_code: test_type.national_code } },
                         { test_type: { national_code: "MOZ-TT-9999", name: "Ferritina" } } ] })

    expect(response).to have_http_status(:created)

    added = order.reload.order_tests.find_by(test_code: "MOZ-TT-9999")
    expect(added.test_type).to be_nil
    expect(added.test_name).to eq("Ferritina")
    expect(added.test_type_label).to eq("Ferritina")
  end

  it "takes a test named with nothing but its name" do
    add_tests({ tests: [ { test_type: "Ferritina" } ] })

    expect(response).to have_http_status(:created)
    expect(order.reload.order_tests.last.test_name).to eq("Ferritina")
  end

  # The one refusal left: a test with no exam on it is not a loose end anybody
  # can tie up later, because nobody would know what was asked for.
  it "refuses a test that names nothing at all, by position" do
    add_tests({ tests: [ { test_type: { national_code: test_type.national_code } },
                         { method_of_testing: "PCR" } ] })

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("errors", 0, "field")).to eq("tests[1].test_type")
    expect(order.reload.order_tests).to be_empty
  end

  it "refuses an empty request" do
    add_tests({ tests: [] })

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("errors", 0, "field")).to eq("tests")
  end

  # A test added to a sample that has been thrown away would sit in a queue for
  # ever.
  it "refuses to add work to a sample that is finished with" do
    order.transition_to!(Order::CANCELLED)

    add_tests(one_test)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("errors", 0, "message")).to include(Order::CANCELLED)
    expect(order.reload.order_tests).to be_empty
  end

  it "answers 403 for a key that may read but not publish" do
    reader = issue_key(api_client: api_client, scopes: %w[orders:read])

    add_tests(one_test, bearer: reader.last)

    expect(response).to have_http_status(:forbidden)
  end

  it "answers 404 for a number this node never issued" do
    add_tests(one_test, tracking_number: "MZ-HCM-26229-9999")

    expect(response).to have_http_status(:not_found)
  end
end
