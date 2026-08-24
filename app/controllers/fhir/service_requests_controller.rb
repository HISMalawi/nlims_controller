# frozen_string_literal: true

module Fhir
  # Where an EMR asks for tests, and follows what it asked for.
  #
  # A ServiceRequest is one test. Posting one creates an order carrying that
  # test; posting one whose code names a panel creates an order carrying every
  # test in the panel, and the answer is then a `collection` Bundle of them —
  # the laboratory runs the members one at a time, and a client that ordered a
  # panel has to learn the identifiers of what it actually got.
  class ServiceRequestsController < Fhir::BaseController
    def create
      return unless authorize_scope!("orders:write")

      key = idempotency_key
      if key.blank?
        return render_api_error(
          Api::Errors::IDEMPOTENCY_KEY_REQUIRED,
          message: "envie o cabeçalho Idempotency-Key ou identifique o pedido em ServiceRequest.identifier",
          field: "ServiceRequest.identifier"
        )
      end

      idempotent(key: key) do
        orders = Fhir::OrderIntake.call!(fhir_body, api_client: Current.api_client)

        render_created(orders)
      end
    end

    def show
      return unless authorize_scope!("orders:read")

      order_test = OrderTest.joins(:order).find_by!(uuid: params[:id])
      return unless authorize_facility!(order_test.order.sending_facility_code)

      render_resource(Fhir::ServiceRequestResource.call(order_test))
    end

    def index
      return unless authorize_scope!("orders:read")

      tests = search.limit(count).to_a

      render_resource(
        Fhir::Bundle.searchset(
          tests.map { |order_test| Fhir::ServiceRequestResource.call(order_test) },
          base_url: fhir_base_url,
          self_url: search_url
        )
      )
    end

    private

    def render_created(orders)
      tests = orders.flat_map { |order| order.order_tests.to_a }
      resources = tests.map { |order_test| Fhir::ServiceRequestResource.call(order_test) }

      if resources.one?
        render_resource(resources.first, status: :created,
                                         location: "#{fhir_base_url}/ServiceRequest/#{tests.first.uuid}")
      else
        render_resource(Fhir::Bundle.collection(resources, base_url: fhir_base_url), status: :created)
      end
    end

    # The header if the client sent one, otherwise the placer order number it
    # put on the request. A retry of the same order carries the same placer
    # number, which is the whole reason that field exists.
    def idempotency_key
      request.headers["Idempotency-Key"].presence || Fhir::OrderIntake.placer_identifier(fhir_body)
    end

    # `requisition` and `identifier` both mean the tracking number here: it is
    # the group identifier of the tests on one tube, and it is also the only
    # identifier the EMR was given, so it must find them either way.
    def search
      relation = OrderTest.joins(order: :patient)
                          .includes(:test_type, :test_panel, order: :patient)
                          .order(id: :desc)

      relation = facility_scope(relation)
      relation = by_tracking_number(relation)
      relation = by_patient(relation)
      by_status(relation)
    end

    def by_tracking_number(relation)
      tracking = token_value(params[:requisition].presence || params[:identifier])
      return relation if tracking.blank?

      relation.where(orders: { tracking_number: tracking })
    end

    def by_patient(relation)
      national_id = token_value(params[:"patient.identifier"] || params[:"subject.identifier"])
      if national_id.present?
        return relation.where(patients: { national_id: Patient.normalize_value_for(:national_id, national_id) })
      end

      uuid = params[:patient].presence || params[:subject].presence
      return relation if uuid.blank?

      relation.where(patients: { uuid: uuid.to_s.delete_prefix("Patient/") })
    end

    # Searching by FHIR's status means searching by every native status that
    # maps to it — `active` is six of them — which is why the mapping is a table
    # and not a case statement.
    def by_status(relation)
      status = params[:status].presence
      return relation if status.blank?

      native = Fhir::ORDER_STATUS.select { |_, mapped| mapped == status }.keys
      relation.where(orders: { status: native })
    end
  end
end
