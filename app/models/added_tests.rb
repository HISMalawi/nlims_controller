# frozen_string_literal: true

# Tests the laboratory adds to a sample it already has.
#
# The clinician asked for two things; the first result made a third necessary.
# Adding it here keeps one sample, one tracking number and one report, which is
# what the clinic is waiting on — the alternative is a second order for a tube
# that was never collected twice.
#
# The same test may be added again on purpose: repeating one is how a laboratory
# confirms a reading it does not believe.
class AddedTests
  def initialize(order, payload, actor:)
    @order = order
    @payload = payload.to_h.deep_symbolize_keys
    @actor = actor
  end

  def add!
    raise InvalidRequest.new("é preciso indicar pelo menos um teste", field: "tests") if rows.empty?

    # A sample that has been rejected or cancelled cannot take more work; a test
    # added to it would sit in a queue for ever.
    if @order.terminal?
      raise InvalidRequest.new("#{@order.tracking_number} está #{@order.status} e não aceita mais testes",
                               field: "tests")
    end

    resolved = rows.each_with_index.map { |row, index| resolve(row, index) }

    Order.transaction do
      added = resolved.map { |row| create_test(row) }

      # The order row itself has not changed, but what it asks for has. The feed
      # ships an order with its tests, so the order has to move or the addition
      # reaches nobody.
      @order.touch_revision!

      added
    end
  end

  private

  def rows
    @rows ||= Array(@payload[:tests])
  end

  def resolve(row, index)
    {
      test_type: Dictionary.entry!("test_types", row[:test_type], field: "tests[#{index}].test_type"),
      method_of_testing: row[:method_of_testing]
    }
  end

  def create_test(resolved)
    @order.order_tests.create!(
      test_type: resolved[:test_type],
      method_of_testing: resolved[:method_of_testing],
      status_actor: @actor
    )
  end
end
