# frozen_string_literal: true

require "json_schemer"

# Checking every answer the suite provokes against the shape ApiContract
# publishes for it.
#
# The document is read by the app — see app/models/api_contract.rb — and this is
# only the half that belongs to the tests: given a response, does it match what
# the contract promised. A serializer that grows a field, or an endpoint that
# starts answering 409 where the document says it cannot, fails here, in the
# spec that exercises it, naming the field.
module OpenapiContract
  class Violation < StandardError; end

  class << self
    # Raises with everything needed to fix it: which operation, which pointer
    # inside the body, and what was there instead.
    def validate_response!(verb:, path:, status:, body:)
      operation = ApiContract.operation_for(verb, path)
      raise Violation, "#{verb} #{path} is not in #{relative_document_path}" if operation.nil?

      schema = response_schema(operation, status)
      if schema.nil?
        raise Violation, "#{operation} answered #{status}, which #{relative_document_path} does not describe"
      end

      errors = schemer(schema).validate(body).to_a
      return true if errors.empty?

      raise Violation, "#{operation} answered #{status} in a shape the contract does not allow:\n" +
                       errors.first(10).map { |error| "  #{describe(error)}" }.join("\n")
    end

    # The declared schema for one answer, or nil where the document does not
    # describe that status at all — which is itself a finding, and is reported by
    # the caller rather than passed over here.
    def response_schema(operation, status)
      response = operation.responses[status.to_s]
      return nil if response.nil?

      ApiContract.resolve(response).dig("content", "application/json", "schema")
    end

    def relative_document_path
      ApiContract::PATH.relative_path_from(Rails.root).to_s
    end

    private

    # `components` travels with each subschema so that every `$ref` in the
    # document resolves against a root that has them, without the whole document
    # having to be a valid JSON Schema in its own right.
    def schemer(schema)
      @schemers ||= {}
      @schemers[schema.object_id] ||= JSONSchemer.schema(
        schema.merge("components" => ApiContract.source.fetch("components")),
        meta_schema: JSONSchemer.draft202012
      )
    end

    def describe(error)
      pointer = error["data_pointer"].presence || "(o corpo)"
      "#{pointer}: #{error['type']} — #{error['data'].inspect.truncate(120)}"
    end
  end
end

# Checked as the requests happen rather than in an `after` hook, so an example
# that makes three calls has all three checked and not only the last.
module ValidatesAgainstTheContract
  def process(method, path, **)
    super.tap { validate_against_contract(method) }
  end

  private

  def validate_against_contract(method)
    return unless RSpec.configuration.validate_openapi_contract
    return unless request.path.start_with?(ApiContract::DOCUMENTED_PREFIX)
    return unless response.media_type == "application/json"

    OpenapiContract.validate_response!(
      verb: method, path: request.path, status: response.status, body: response.parsed_body
    )
  end
end

ActionDispatch::Integration::Session.prepend(ValidatesAgainstTheContract)

RSpec.configure do |config|
  # On by default: the contract is worth having because it is checked
  # everywhere, not because a few examples were written to check it.
  config.add_setting :validate_openapi_contract, default: true

  config.around(contract: false) do |example|
    RSpec.configuration.validate_openapi_contract = false
    example.run
  ensure
    RSpec.configuration.validate_openapi_contract = true
  end
end
