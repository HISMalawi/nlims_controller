# frozen_string_literal: true

# What an EMR sends to ask for tests, turned into records.
#
# Terms are matched against the dictionary and kept as they were written when
# the match fails. The rule used to be the other way round — an unknown code
# refused the whole request — and it was refusing real work, because the
# national dictionary is still being assembled. What is stored now is enough to
# link the term later: the code it arrived with, the name it arrived with, and
# the entry when there was one.
class OrderRequest
  def initialize(payload, api_client:)
    @payload = payload.to_h.deep_symbolize_keys
    @api_client = api_client
  end

  # The facility the order is being raised for. Read from the key, or from this
  # node's own entry in the register — never from the payload. A client that
  # sends one is not disbelieved so much as not consulted: it is describing
  # something the node already knows, and the two disagreeing was a 403 that
  # stopped integrations for a reason nobody could see from the outside.
  def facility_code
    @api_client&.facility_code.presence || SislabSync.facility_code
  end

  # The laboratory that will run the tests. Defaults to this node's own: a
  # laboratory node receiving an order is, overwhelmingly, the laboratory that
  # will do the work, and making every EMR say so was the commonest reason a
  # first request failed.
  def receiving_lab_code
    order_params[:receiving_lab_code].presence || SislabSync.lab_code
  end

  def create!
    validate!

    Order.transaction do
      order = build_order
      order.save!
      build_tests(order)
      order
    end
  end

  private

  def patient_params
    @payload[:patient] || {}
  end

  def order_params
    @payload[:order] || {}
  end

  def test_params
    Array(@payload[:tests])
  end

  # Everything that can be judged before a row is written. What remains after
  # the dictionary stopped being a gate: a request has to ask for something, and
  # each thing it asks for has to have a name.
  def validate!
    raise InvalidRequest.new("é preciso pedir pelo menos um teste", field: "tests") if test_params.empty?

    resolved_tests
  end

  def build_order
    order = Order.new(
      patient: Patient.upsert_from!(patient_params),
      sending_facility_code: facility_code,
      receiving_lab_code: receiving_lab_code,
      lab_code: order_params[:lab_code],
      priority: order_params[:priority].presence || Order::PRIORITIES.first,
      requested_by: order_params[:requested_by],
      order_location: order_params[:order_location],
      clinical_history: order_params[:clinical_history],
      collected_at: order_params[:collected_at],
      source_system: @api_client&.kind,
      source_client: @api_client,
      status_actor: @api_client&.name
    )

    order.specimen_type_reference = Dictionary::Reference.resolve("specimen_types", order_params[:specimen_type])
    order
  end

  def build_tests(order)
    resolved_tests.each do |test|
      order_test = order.order_tests.new(method_of_testing: test[:method_of_testing],
                                         status_actor: @api_client&.name)
      order_test.test_type_reference = test[:test_type]
      order_test.test_panel_reference = test[:test_panel] if test[:test_panel]
      order_test.save!
    end
  end

  # A panel this node knows is expanded here rather than stored as one row: the
  # laboratory runs the tests inside it one at a time, and each has to be able
  # to be rejected, referred or reported on its own. The panel is remembered on
  # every test it produced, so it can still be reported as a whole.
  #
  # A panel this node does not know cannot be expanded, so it stands as a single
  # test under the name it was asked for. The laboratory adds what it actually
  # ran at the bench, which is what it would have had to do anyway.
  def resolved_tests
    @resolved_tests ||= test_params.flat_map.with_index do |test, index|
      if test[:test_panel].present?
        panel = Dictionary::Reference.resolve!("test_panels", test[:test_panel],
                                               field: "tests[#{index}].test_panel",
                                               message: "é preciso indicar o painel, por código ou por nome")
        expand_panel(panel, test)
      else
        reference = Dictionary::Reference.resolve!("test_types", test[:test_type],
                                                   field: "tests[#{index}].test_type",
                                                   message: "é preciso indicar o exame, por código ou por nome")
        [ { test_type: reference, test_panel: nil, method_of_testing: test[:method_of_testing] } ]
      end
    end
  end

  def expand_panel(panel, test)
    members = panel.known? ? panel.entry.test_types.active.to_a : []

    return [ { test_type: panel, test_panel: panel, method_of_testing: test[:method_of_testing] } ] if members.empty?

    members.map do |test_type|
      { test_type: Dictionary::Reference.new(entry: test_type),
        test_panel: panel,
        method_of_testing: test[:method_of_testing] }
    end
  end
end
