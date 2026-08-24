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

  # The two dialects the contract speaks for. FHIR resources are JSON under a
  # media type of their own, and a response the document describes must be
  # checked whichever of the two it arrives as.
  MEDIA_TYPES = [ "application/json", "application/fhir+json" ].freeze

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

      content = ApiContract.resolve(response).fetch("content", {})

      MEDIA_TYPES.filter_map { |media_type| content.dig(media_type, "schema") }.first
    end

    # A body the node accepted has to be one the contract would have accepted
    # too. Checked only on success, because plenty of specs send deliberate
    # rubbish to see it refused, and the contract is not describing rubbish.
    #
    # This is the direction that catches an over-strict schema — a field marked
    # required that the node is perfectly happy without — which no amount of
    # validating responses will ever reveal.
    #
    # `answer` is needed because on one endpoint a 2xx does not mean the whole
    # body was taken: /sync/events accepts the batch and names the events it
    # could not apply. Those events are precisely the ones the contract should
    # refuse, so a batch carrying any of them proves nothing either way.
    def validate_request!(verb:, path:, status:, body:, answer: nil)
      return true unless status.between?(200, 299)
      return true if partly_refused?(answer)

      operation = ApiContract.operation_for(verb, path)
      return true if operation.nil?

      schema = operation.definition.dig("requestBody", "content", "application/json", "schema")
      return true if schema.nil?

      errors = schemer(schema).validate(body).to_a
      return true if errors.empty?

      raise Violation, "#{operation} accepted a body the contract would have refused:\n" +
                       errors.first(10).map { |error| "  #{describe(error)}" }.join("\n")
    end

    def relative_document_path
      ApiContract::PATH.relative_path_from(Rails.root).to_s
    end

    private

    def partly_refused?(answer)
      data = answer.is_a?(Hash) ? answer["data"] : nil

      data.is_a?(Hash) && Array(data["rejected"]).any?
    end

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
    return unless ApiContract.documented?(request.path)
    return unless response.media_type.in?(OpenapiContract::MEDIA_TYPES)

    OpenapiContract.validate_response!(
      verb: method, path: request.path, status: response.status, body: response.parsed_body
    )

    sent = request_body_sent
    return if sent.nil?

    OpenapiContract.validate_request!(
      verb: method, path: request.path, status: response.status, body: sent, answer: response.parsed_body
    )
  end

  # Nil unless the spec actually sent a JSON body — a GET, a form post or a
  # bodyless POST has nothing for the contract to check.
  def request_body_sent
    return nil unless request.media_type == "application/json"

    JSON.parse(request.raw_post)
  rescue JSON::ParserError
    nil
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
