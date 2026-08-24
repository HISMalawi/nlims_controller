# frozen_string_literal: true

# `application/fhir+json` is JSON, and the suite should be able to read it as
# such. Without this, `response.parsed_body` hands back the raw string for every
# FHIR response and each expectation has to parse it itself.
ActionDispatch::IntegrationTest.register_encoder(
  :fhir_json,
  param_encoder: ->(params) { params.is_a?(String) ? params : params.to_json },
  response_parser: ->(body) { body.present? ? JSON.parse(body) : body }
)
