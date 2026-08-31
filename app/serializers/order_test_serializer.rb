# frozen_string_literal: true

# One test on the wire.
#
# Results are left out unless asked for: a client following the state of a
# sample wants to know which tests are running, and shipping every reading with
# that answer would make the common call the expensive one.
class OrderTestSerializer
  def self.call(order_test, results: false)
    new(order_test, results: results).as_json
  end

  def initialize(order_test, results: false)
    @order_test = order_test
    @results = results
  end

  def as_json
    base = {
      uuid: @order_test.uuid,
      status: @order_test.status,
      test_type: DictionaryReference.call(@order_test.test_type_reference),
      test_panel: DictionaryReference.call(@order_test.test_panel_reference),
      method_of_testing: @order_test.method_of_testing,
      created_at: @order_test.created_at&.iso8601,
      updated_at: @order_test.updated_at&.iso8601
    }

    return base unless @results

    base.merge(results: results_json)
  end

  private

  # Superseded readings travel too. A client that pulled the wrong value has to
  # be able to see that it was corrected, and by which row.
  def results_json
    @order_test.test_results.sort_by { |result| [ result.recorded_at, result.id ] }
               .map { |result| TestResultSerializer.call(result) }
  end
end
