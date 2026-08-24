# frozen_string_literal: true

module Fhir
  # Base for the FHIR façade.
  #
  # It inherits the JSON API's base controller on purpose: authentication,
  # scopes, the facility rule, rate limiting, idempotency and the audit trail
  # are properties of this node, not of a dialect, and an EMR that switched
  # from one to the other and found the rules different would be right to call
  # that a bug. What changes here is only the shape of what comes back — FHIR
  # resources instead of the `{ data, meta, errors }` envelope, and an
  # OperationOutcome instead of an error list.
  class BaseController < Api::BaseController
    MEDIA_TYPE = "application/fhir+json"

    DEFAULT_COUNT = 100
    MAX_COUNT = 500

    rescue_from JSON::ParserError do
      render_api_error(Api::Errors::UNPROCESSABLE, message: "o corpo do pedido não é JSON válido")
    end

    private

    def render_resource(resource, status: :ok, location: nil)
      response.headers["Location"] = location if location

      render json: resource, status: status, content_type: MEDIA_TYPE
    end

    # Overrides the envelope the JSON API renders. Every refusal in the shared
    # concerns — an expired key, a missing Idempotency-Key, a rate limit — comes
    # through here, so a FHIR client never sees the other dialect's error shape.
    def render_api_error(code, message: nil, field: nil, status: nil)
      render json: Fhir::OperationOutcome.call(code, message: message, field: field),
             status: status || Api::Errors.status_for(code),
             content_type: MEDIA_TYPE
    end

    # The audit trail stores this node's own error code, whatever dialect was
    # speaking. It lives in the OperationOutcome's details coding for exactly
    # this reason.
    def rendered_error_code
      return nil if response.successful?

      body = response.body.presence
      return nil unless body&.start_with?("{")

      JSON.parse(body).dig("issue", 0, "details", "coding", 0, "code")
    rescue JSON::ParserError
      nil
    end

    # The posted resource, as a plain hash. FHIR resources nest far too deeply
    # to be read through strong parameters, and nothing here is ever mass
    # assigned: the intake builds an explicit payload out of the fields it
    # recognises and ignores everything else.
    def fhir_body
      @fhir_body ||= begin
        raw = request.raw_post
        raise JSON::ParserError, "empty body" if raw.blank?

        JSON.parse(raw)
      end
    end

    # What a Bundle's fullUrls and links are relative to.
    def fhir_base_url
      @fhir_base_url ||= "#{request.base_url}/fhir/r4"
    end

    def search_url(overrides = {})
      query = request.query_parameters.merge(overrides.transform_keys(&:to_s))

      "#{request.base_url}#{request.path}#{query.any? ? "?#{query.to_query}" : ''}"
    end

    def count
      @count ||= (params[:_count].presence || DEFAULT_COUNT).to_i.clamp(1, MAX_COUNT)
    end

    # `system|value`, `|value` and a bare `value` all mean the same thing to a
    # client that only ever holds one identifier. FHIR allows all three and an
    # EMR will send whichever its library favours.
    def token_value(raw)
      value = raw.to_s
      return value if value.exclude?("|")

      value.split("|", 2).last.presence
    end

    # Everything this key is allowed to see, and nothing else. The facility rule
    # is applied as a filter on searches rather than as a refusal, because a
    # search that matched nothing is a legitimate empty bundle — it is only
    # naming another facility's resource outright that is refused.
    def facility_scope(relation)
      facility = Current.api_client&.facility_code
      return relation if facility.blank?

      relation.where(orders: { sending_facility_code: facility })
    end
  end
end
