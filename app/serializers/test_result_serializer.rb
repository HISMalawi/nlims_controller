# frozen_string_literal: true

# One reading on the wire.
class TestResultSerializer
  def self.call(result)
    {
      uuid: result.uuid,
      indicator: DictionaryReference.call(result.indicator),
      value: result.value,
      unit: result.unit,
      recorded_at: result.recorded_at&.iso8601,
      recorded_by: result.recorded_by,
      replaced_by_uuid: result.replaced_by_uuid
    }
  end
end
