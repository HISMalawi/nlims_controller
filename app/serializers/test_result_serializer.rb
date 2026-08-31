# frozen_string_literal: true

# One reading on the wire.
#
# A client polling the results feed gets the same reading with the context it
# would otherwise have to fetch an order to discover: which sample it belongs
# to, whose it is, and which test produced it.
class TestResultSerializer
  def self.call(result, context: false)
    new(result, context: context).as_json
  end

  def initialize(result, context: false)
    @result = result
    @context = context
  end

  def as_json
    return base unless @context

    base.merge(
      tracking_number: @result.order_test.tracking_number,
      order_test_uuid: @result.order_test.uuid,
      test_type: DictionaryReference.call(@result.order_test.test_type_reference),
      patient: PatientSerializer.call(@result.order_test.order.patient)
    )
  end

  private

  def base
    {
      uuid: @result.uuid,
      revision: @result.revision,
      indicator: DictionaryReference.call(@result.indicator_reference),
      value: @result.value,
      unit: @result.unit,
      recorded_at: @result.recorded_at&.iso8601,
      recorded_by: @result.recorded_by,
      replaced_by_uuid: @result.replaced_by_uuid,
      acknowledged_at: @result.acknowledged_at&.iso8601
    }
  end
end
