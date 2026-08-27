# frozen_string_literal: true

module Fhir
  # A refusal, in the only shape FHIR has for one.
  #
  # Every issue carries two codes: FHIR's own, which a generic client branches
  # on, and this node's, which is the code the rest of the API already publishes
  # and is stable across wordings and translations. An integrator debugging one
  # dialect should not have to learn a second vocabulary of error codes.
  class OperationOutcome
    TYPE = "OperationOutcome"

    ISSUE_TYPES = {
      Api::Errors::UNAUTHENTICATED => "login",
      Api::Errors::INSUFFICIENT_SCOPE => "forbidden",
      Api::Errors::LAB_MISMATCH => "forbidden",
      Api::Errors::IDEMPOTENCY_KEY_REQUIRED => "required",
      Api::Errors::IDEMPOTENCY_KEY_REUSED => "duplicate",
      Api::Errors::RATE_LIMITED => "throttled",
      Api::Errors::NOT_FOUND => "not-found",
      Api::Errors::CONFLICT => "conflict",
      Api::Errors::UNPROCESSABLE => "invalid"
    }.freeze

    DEFAULT_ISSUE_TYPE = "processing"

    def self.call(code, message: nil, field: nil, severity: "error")
      {
        resourceType: TYPE,
        issue: [
          {
            severity: severity,
            code: ISSUE_TYPES.fetch(code, DEFAULT_ISSUE_TYPE),
            details: {
              coding: [ { system: Fhir.url("CodeSystem/error-code"), code: code } ],
              text: message || Api::Errors.message_for(code)
            },
            # Which field was wrong, where the node knows. FHIRPath is what a
            # client expects here, and the intake reports the JSON field it
            # actually read, so the two are the same string.
            expression: field ? [ field ] : nil
          }.compact
        ]
      }
    end
  end
end
