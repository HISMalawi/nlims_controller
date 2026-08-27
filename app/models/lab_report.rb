# frozen_string_literal: true

# What a laboratory publishes about a sample it is working on.
#
# Readings arrive as they come off the bench, so a report is normally partial:
# `final` is what says a test is finished, not the presence of a value. Sending
# the same indicator again is a correction, and the model keeps both readings.
class LabReport
  def initialize(order, payload, actor:)
    @order = order
    @payload = payload.to_h.deep_symbolize_keys
    @actor = actor
  end

  def record!
    raise InvalidRequest.new("é preciso enviar pelo menos um resultado", field: "results") if rows.empty?

    # Resolved before anything is written, so a report naming one test that is
    # not on this sample stores none of its readings.
    resolved = rows.each_with_index.map { |row, index| resolve(row, index) }

    TestResult.transaction do
      resolved.each { |row| record_one(row) }
      resolved.map { |row| row[:order_test] }.uniq.each { |order_test| finish(order_test) } if final?
    end

    @order.reload
  end

  private

  def rows
    @rows ||= Array(@payload[:results])
  end

  def final?
    ActiveModel::Type::Boolean.new.cast(@payload[:final]).present?
  end

  def resolve(row, index)
    field = "results[#{index}].test_type"
    test = Dictionary::Reference.resolve!("test_types", row[:test_type], field: field,
                                          message: "é preciso indicar o exame, por código ou por nome")
    order_test = find_test(test)

    if order_test.nil?
      raise InvalidRequest.new("#{test.description} não faz parte de #{@order.tracking_number}", field: field)
    end

    {
      order_test: order_test,
      indicator: Dictionary::Reference.resolve!("indicators", row[:indicator],
                                                field: "results[#{index}].indicator",
                                                message: "é preciso indicar o indicador, por código ou por nome"),
      row: row
    }
  end

  # Which test on this sample the reading belongs to. A term the dictionary
  # carries is matched by its entry; one it does not is matched by the name the
  # order was raised under, which is what the laboratory is reading off its own
  # worksheet. This refusal stays: a reading for a test nobody asked for is a
  # reading filed against the wrong sample, and no amount of loosening the
  # dictionary makes that safe.
  def find_test(reference)
    tests = @order.order_tests.to_a

    if reference.known?
      tests.find { |test| test.test_type_id == reference.entry.id }
    else
      tests.find { |test| test.test_name.to_s.casecmp?(reference.name.to_s) } ||
        tests.find { |test| test.test_code.present? && test.test_code == reference.code }
    end
  end

  def record_one(resolved)
    order_test = resolved[:order_test]

    # A reading is evidence the test is being worked on, so a test still sitting
    # in the queue moves itself rather than making the laboratory send a second
    # request to say what its first request already proved.
    start(order_test)

    TestResult.record!(
      order_test: order_test,
      indicator: resolved[:indicator],
      value: resolved[:row][:value],
      unit: resolved[:row][:unit],
      recorded_at: resolved[:row][:recorded_at],
      recorded_by: resolved[:row][:recorded_by].presence || @actor
    )
  end

  def start(order_test)
    return unless order_test.status == OrderTest::PENDING

    order_test.transition_to!(OrderTest::IN_PROGRESS, actor: @actor)
  end

  # A test that has already been rejected or cancelled is left where it is: a
  # late reading does not undo the rejection.
  def finish(order_test)
    return unless order_test.may_transition_to?(OrderTest::COMPLETED)

    order_test.transition_to!(OrderTest::COMPLETED, actor: @actor)
  end
end
