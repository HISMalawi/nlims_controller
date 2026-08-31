# frozen_string_literal: true

# FHIR speaks its own media type, and a client that sets it must not be met
# with a body Rails declined to parse. Registering it here means `application/
# fhir+json` behaves exactly like `application/json` everywhere in the stack —
# content negotiation, parameter parsing and the request logs.
Mime::Type.register "application/fhir+json", :fhir_json unless Mime::Type.lookup_by_extension(:fhir_json)

ActionDispatch::Request.parameter_parsers[:fhir_json] =
  ActionDispatch::Request.parameter_parsers[:json] ||
  ->(raw_post) { ActiveSupport::JSON.decode(raw_post) }
