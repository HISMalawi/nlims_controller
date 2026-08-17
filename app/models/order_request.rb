# frozen_string_literal: true

# What an EMR sends to ask for tests, turned into records.
#
# Everything the EMR names is addressed by dictionary code, never by free text.
# A code this node does not know is refused by name, so the integrator learns
# that their dictionary is behind — the current system accepts the name it was
# given and the test quietly becomes something nobody can report on.
class OrderRequest
  # Carries the field it happened in, so the client is told which of fifteen
  # codes in the payload was the problem rather than being handed a flat "422".
  class Invalid < StandardError
    attr_reader :field

    def initialize(message, field:)
      super(message)
      @field = field
    end
  end

  def initialize(payload, api_client:)
    @payload = payload.to_h.deep_symbolize_keys
    @api_client = api_client
  end

  # The facility the order is being raised for. Taken from the key when the
  # payload leaves it out: the key already knows which facility it speaks for,
  # and an EMR should not have to repeat it to be believed.
  def facility_code
    order_params[:sending_facility_code].presence || @api_client&.facility_code
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

  # Everything that can be judged before a row is written. The dictionary
  # lookups happen here too, so an order with one unknown test code writes
  # nothing at all rather than an order that is missing a test.
  def validate!
    raise Invalid.new("é preciso pedir pelo menos um teste", field: "tests") if test_params.empty?
    raise Invalid.new("o pedido tem de indicar o laboratório receptor", field: "order.receiving_lab_code") if
      order_params[:receiving_lab_code].blank?

    specimen_type
    resolved_tests
  end

  def build_order
    Order.new(
      patient: Patient.upsert_from!(patient_params),
      specimen_type: specimen_type,
      sending_facility_code: facility_code,
      receiving_lab_code: order_params[:receiving_lab_code],
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
  end

  def build_tests(order)
    resolved_tests.each do |test|
      order.order_tests.create!(
        test_type: test[:test_type],
        test_panel: test[:test_panel],
        method_of_testing: test[:method_of_testing],
        status_actor: @api_client&.name
      )
    end
  end

  def specimen_type
    return @specimen_type if defined?(@specimen_type)

    reference = order_params[:specimen_type]
    @specimen_type = reference.blank? ? nil : resolve!("specimen_types", reference, field: "order.specimen_type")
  end

  # A panel is expanded here rather than being stored as one row: the laboratory
  # runs the tests inside it one at a time, and each has to be able to be
  # rejected, referred or reported on its own. The panel is remembered on every
  # test it produced, so it can still be reported as a whole.
  def resolved_tests
    @resolved_tests ||= test_params.flat_map.with_index do |test, index|
      if test[:test_panel].present?
        expand_panel(test, index)
      else
        [ { test_type: resolve!("test_types", test[:test_type] || {}, field: "tests[#{index}].test_type"),
            test_panel: nil, method_of_testing: test[:method_of_testing] } ]
      end
    end
  end

  def expand_panel(test, index)
    field = "tests[#{index}].test_panel"
    panel = resolve!("test_panels", test[:test_panel], field: field)
    members = panel.test_types.active.to_a

    if members.empty?
      raise Invalid.new("o painel #{panel.national_code} (#{panel.name}) não tem testes activos", field: field)
    end

    members.map do |test_type|
      { test_type: test_type, test_panel: panel, method_of_testing: test[:method_of_testing] }
    end
  end

  def resolve!(entity_type, reference, field:)
    model = Dictionary.model_for!(entity_type)
    code = reference[:national_code].presence
    uuid = reference[:uuid].presence

    raise Invalid.new("é preciso indicar national_code ou uuid", field: field) if code.blank? && uuid.blank?

    entry = code ? model.find_by(national_code: code) : model.find_by(uuid: uuid)
    raise Invalid.new("o código #{code || uuid} não existe no dicionário deste nó", field: field) if entry.nil?

    unless entry.active?
      raise Invalid.new("#{entry.national_code} (#{entry.name}) não está activo no dicionário " \
                        "(status: #{entry.status})", field: field)
    end

    entry
  end
end
