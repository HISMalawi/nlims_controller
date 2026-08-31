# frozen_string_literal: true

module Fhir
  # GET /fhir/r4/metadata — the contract, served by the node it describes.
  #
  # Open, like /api-docs and for the same reason: it is what a team reads before
  # they have a key, and a contract you need credentials to read is one every
  # integrator will instead reconstruct by guessing.
  class CapabilityController < Fhir::BaseController
    skip_before_action :authenticate_api_client!

    def show
      render_resource(Fhir::CapabilityStatement.call(base_url: fhir_base_url))
    end
  end
end
