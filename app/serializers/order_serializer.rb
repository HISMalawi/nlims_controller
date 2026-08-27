# frozen_string_literal: true

# One order on the wire, in the shape the EMR, the SISLAB and the national node
# all receive. There is one serializer rather than one per audience: the three
# integrations disagreeing about what an order looks like is how the current
# system ended up translating between three shapes of the same record.
class OrderSerializer
  def self.call(order, results: false, history: false)
    new(order, results: results, history: history).as_json
  end

  def initialize(order, results: false, history: false)
    @order = order
    @results = results
    @history = history
  end

  def as_json
    json = base.merge(tests: tests_json)
    json = json.merge(history: history_json) if @history
    json
  end

  private

  def base
    {
      uuid: @order.uuid,
      revision: @order.revision,
      tracking_number: @order.tracking_number,
      status: @order.status,
      priority: @order.priority,
      claimed_at: @order.claimed_at&.iso8601,
      claimed_by_lab_code: @order.claimed_by_lab_code,
      sending_facility_code: @order.sending_facility_code,
      receiving_lab_code: @order.receiving_lab_code,
      lab_code: @order.lab_code,
      specimen_type: DictionaryReference.call(@order.specimen_type_reference),
      collected_at: @order.collected_at&.iso8601,
      requested_by: @order.requested_by,
      order_location: @order.order_location,
      clinical_history: @order.clinical_history,
      source_system: @order.source_system,
      patient: PatientSerializer.call(@order.patient),
      # The parcel this sample is travelling on, if it is. A laboratory looking
      # at a referred sample needs to know where it came from without being told
      # to go and ask.
      referral: ReferralSerializer.call(@order.referrals.max_by(&:dispatched_at)),
      created_at: @order.created_at&.iso8601,
      updated_at: @order.updated_at&.iso8601
    }
  end

  def tests_json
    @order.order_tests.map { |test| OrderTestSerializer.call(test, results: @results) }
  end

  def history_json
    @order.status_events.map { |event| StatusEventSerializer.call(event) }
  end
end
