# frozen_string_literal: true

module Fhir
  # The sample, addressed by the same uuid as the order it is.
  #
  # There is no specimens table: one order is one sample here, so the Specimen
  # is a projection of the order and exists so that a client following
  # `ServiceRequest.specimen` finds something at the other end rather than a 404.
  class SpecimensController < Fhir::BaseController
    def show
      return unless authorize_scope!("orders:read")

      order = Order.find_by!(uuid: params[:id])
      return unless authorize_facility!(order.sending_facility_code)

      render_resource(Fhir::SpecimenResource.call(order))
    end
  end
end
