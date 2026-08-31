# frozen_string_literal: true

require "rails_helper"

# S6 is done when creating an order with three tests, walking the states and
# recording results produces a complete history with one event per transition.
# This is that sentence, written out.
RSpec.describe "an order from request to result", type: :model do
  let(:patient) { create(:patient, :identified, name: "Ana Macuácua") }
  let(:specimen_type) { create(:specimen_type, name: "Sangue total") }
  let(:haemoglobin) { create(:indicator, name: "Hemoglobina", unit: "g/dL") }

  it "leaves a complete history and one current reading per indicator" do
    order = create(:order, patient: patient, specimen_type: specimen_type)
    tests = create_list(:order_test, 3, order: order)

    order.transition_to!(Order::ACCEPTED, actor: "rec.chissano", reason: "amostra recebida")
    order.transition_to!(Order::SPECIMEN_COLLECTED, actor: "enf.langa")
    order.transition_to!(Order::IN_PROGRESS, actor: "tec.mabjaia")

    tests.each { |test| test.transition_to!(OrderTest::IN_PROGRESS, actor: "tec.mabjaia") }

    tests.each do |test|
      TestResult.record!(order_test: test, indicator: haemoglobin, value: "12.4",
                         unit: "g/dL", recorded_by: "tec.mabjaia")
      test.transition_to!(OrderTest::COMPLETED, actor: "tec.mabjaia")
    end

    # A reading that turns out to be wrong on one of them.
    TestResult.record!(order_test: tests.first, indicator: haemoglobin, value: "14.2",
                       unit: "g/dL", recorded_by: "dr.sitoe")

    order.transition_to!(Order::COMPLETED, actor: "dr.sitoe")

    # Four transitions on the order, two on each of the three tests, and the
    # event each of the four records was born with.
    expect(order.status_events.count).to eq(4 + (3 * 2) + 4)
    expect(order.own_status_events.map(&:to_status))
      .to eq([ Order::REQUESTED, Order::ACCEPTED, Order::SPECIMEN_COLLECTED,
               Order::IN_PROGRESS, Order::COMPLETED ])
    expect(order.own_status_events.map(&:actor))
      .to eq([ nil, "rec.chissano", "enf.langa", "tec.mabjaia", "dr.sitoe" ])

    # Every event sits under the tracking number an operator would search for,
    # and every one names who moved it.
    expect(order.status_events.map(&:tracking_number).uniq).to eq([ order.tracking_number ])
    expect(order.status_events.map(&:from_status).compact.length).to eq(4 + (3 * 2))

    # The correction did not overwrite: four readings recorded, one of them
    # superseded, three currently valid.
    expect(order.test_results.count).to eq(4)
    expect(tests.first.current_results.map(&:value)).to eq([ "14.2" ])
    expect(order.test_results.current.count).to eq(3)

    superseded = tests.first.test_results.replaced.sole
    expect(superseded.value).to eq("12.4")
    expect(superseded.replaced_by).to eq(tests.first.current_results.sole)
  end

  it "renders the whole thing for the APIs that come next" do
    order = create(:order, patient: patient, specimen_type: specimen_type)
    order_test = create(:order_test, order: order)
    TestResult.record!(order_test: order_test, indicator: haemoglobin, value: "12.4", unit: "g/dL")

    json = OrderSerializer.call(order, results: true, history: true)

    expect(json[:tracking_number]).to eq(order.tracking_number)
    expect(json[:patient][:national_id]).to eq(patient.national_id)
    expect(json[:specimen_type][:national_code]).to eq(specimen_type.national_code)
    expect(json[:tests].sole[:test_type][:national_code]).to eq(order_test.test_type.national_code)
    expect(json[:tests].sole[:results].sole[:value]).to eq("12.4")
    expect(json[:tests].sole[:results].sole[:indicator][:national_code]).to eq(haemoglobin.national_code)
    expect(json[:history].map { |event| event[:to_status] }).to eq([ Order::REQUESTED, OrderTest::PENDING ])
  end

  # Nothing crosses a node boundary by id: they mean nothing on the other side
  # and would point at the wrong record after a re-seed.
  it "addresses everything by uuid or national code, never by id" do
    order = create(:order, patient: patient, specimen_type: specimen_type)
    create(:order_test, order: order)

    json = OrderSerializer.call(order, results: true, history: true)

    expect(json.to_json).not_to match(/"(id|patient_id|specimen_type_id|test_type_id)":/)
  end
end
