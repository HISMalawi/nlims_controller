# frozen_string_literal: true

module Fhir
  # The people this node holds samples for.
  #
  # Read-only, and only reachable through the orders the key's facility raised:
  # this is a laboratory node, not a patient registry, and a key that can order
  # tests should not double as a way to enumerate the country's patients.
  class PatientsController < Fhir::BaseController
    def show
      return unless authorize_scope!("orders:read")

      patient = visible_patients.find_by!(uuid: params[:id])

      render_resource(Fhir::PatientResource.call(patient))
    end

    def index
      return unless authorize_scope!("orders:read")

      patients = visible_patients.where(national_id: searched_national_id).limit(count).to_a

      render_resource(
        Fhir::Bundle.searchset(
          patients.map { |patient| Fhir::PatientResource.call(patient) },
          base_url: fhir_base_url,
          self_url: search_url
        )
      )
    end

    private

    # A search with no identifier answers nothing rather than everything. An
    # empty `identifier` parameter is a client bug, and a list of every patient
    # in the facility is not a useful accident to hand it.
    def searched_national_id
      Patient.normalize_value_for(:national_id, token_value(params[:identifier])) || ""
    end

    def visible_patients
      facility = Current.api_client&.facility_code
      scope = Patient.where(id: Order.select(:patient_id))
      return scope if facility.blank?

      scope.where(id: Order.where(sending_facility_code: facility).select(:patient_id))
    end
  end
end
