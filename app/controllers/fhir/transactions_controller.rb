# frozen_string_literal: true

module Fhir
  # A transaction Bundle posted to the base URL.
  #
  # This is how an EMR asks for several tests on one sample in one call: a
  # Patient, a Specimen and one ServiceRequest per test, grouped by
  # `requisition`. It is the FHIR equivalent of the JSON intake's `tests` array,
  # and it goes through the same OrderRequest — a bundle whose third test names
  # a code this node does not know writes nothing at all, rather than an order
  # missing a test.
  class TransactionsController < Fhir::BaseController
    TRANSACTION = "transaction"

    def create
      return unless authorize_scope!("orders:write")
      return unless bundle_is_a_transaction?

      key = idempotency_key
      if key.blank?
        return render_api_error(
          Api::Errors::IDEMPOTENCY_KEY_REQUIRED,
          message: "envie o cabeçalho Idempotency-Key ou identifique o pedido em ServiceRequest.identifier",
          field: "Bundle.entry.resource.identifier"
        )
      end

      idempotent(key: key) do
        orders = Fhir::OrderIntake.call!(fhir_body, api_client: Current.api_client)
        resources = orders.flat_map(&:order_tests)
                          .map { |order_test| Fhir::ServiceRequestResource.call(order_test) }

        render_resource(Fhir::Bundle.transaction_response(resources, base_url: fhir_base_url), status: :created)
      end
    end

    private

    # `batch` is deliberately refused rather than quietly treated as a
    # transaction: a batch promises that entries succeed independently, and this
    # intake is all-or-nothing by design.
    def bundle_is_a_transaction?
      type = fhir_body["type"]
      return true if type == TRANSACTION

      render_api_error(
        Api::Errors::UNPROCESSABLE,
        message: "este endpoint aceita apenas Bundle de tipo `transaction`, recebi #{type.inspect}",
        field: "Bundle.type"
      )
      false
    end

    def idempotency_key
      request.headers["Idempotency-Key"].presence || Fhir::OrderIntake.placer_identifier(fhir_body)
    end
  end
end
