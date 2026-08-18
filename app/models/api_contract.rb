# frozen_string_literal: true

# The published API contract — docs/sislab-sync/openapi.yaml — and the little
# that is needed to read it.
#
# The file describes the whole system. A node serves only its own half: an
# integrator pointed at a laboratory node should not find the national node's
# endpoints in the reference and go looking for routes that are not there. Which
# half is which comes from `x-node-mode` on each operation, the same distinction
# config/routes.rb draws when it decides what to route at all.
#
# This is also what the suite validates responses against, so there is one
# reader of the document rather than one for the app and one for the specs.
class ApiContract
  PATH = Rails.root.join("docs/sislab-sync/openapi.yaml")

  # The verbs that carry an operation. Anything else under a path item —
  # `parameters`, `summary` — is not one.
  VERBS = %w[get put post delete options head patch trace].freeze

  # Everything the contract speaks for. The operator interface, the container
  # health check and the assets are outside it and none of its business.
  DOCUMENTED_PREFIX = "/api/v3/"

  Operation = Struct.new(:template, :verb, :definition, keyword_init: true) do
    def node_mode = definition["x-node-mode"]
    def scope = definition["x-scope"]
    def id = definition["operationId"]
    def summary = definition["summary"]
    def description = definition["description"]
    def tag = definition.fetch("tags", []).first
    def responses = definition.fetch("responses", {})
    def parameters = definition.fetch("parameters", [])
    def authenticated? = definition["security"] != []
    def to_s = "#{verb} #{template}"

    # `/api/v3/orders/{tracking_number}` against `/api/v3/orders/HCM26000123`.
    def matches?(path)
      @pattern ||= begin
        segments = template.split("/", -1).map do |segment|
          segment.start_with?("{") ? "[^/]+" : Regexp.escape(segment)
        end

        /\A#{segments.join('/')}\z/
      end

      @pattern.match?(path)
    end
  end

  class << self
    # The whole document, as written. Re-read in development so that editing the
    # contract does not need a restart; read once anywhere else.
    def source
      return load_document if Rails.env.development?

      @source ||= load_document
    end

    # What this node answers, and nothing else.
    def this_node
      source.merge(
        "paths" => source.fetch("paths").filter_map do |template, item|
          kept = item.select do |key, definition|
            !key.in?(VERBS) || runs_here?(Operation.new(template: template, verb: key, definition: definition))
          end

          [ template, kept ] if kept.any? { |key, _| key.in?(VERBS) }
        end.to_h
      )
    end

    # Concrete paths first. `/dictionary/changes` and `/dictionary/{entity_type}`
    # both match the same request, and only one of them is right.
    def operations(document = source)
      document.fetch("paths").flat_map do |template, item|
        item.slice(*VERBS).map do |verb, definition|
          Operation.new(template: template, verb: verb.upcase, definition: definition)
        end
      end.sort_by { |operation| operation.template.count("{") }
    end

    def operation_for(verb, path, document = source)
      operations(document).find { |operation| operation.verb == verb.to_s.upcase && operation.matches?(path) }
    end

    def runs_here?(operation)
      case operation.node_mode
      when "local" then SislabSync.local?
      when "national" then SislabSync.national?
      else true
      end
    end

    # Follows a local `#/...` pointer. The document uses no others: a contract
    # that has to be fetched from somewhere else to be read is not one an
    # integrator can rely on having.
    def resolve(node, document = source)
      pointer = node.is_a?(Hash) ? node["$ref"] : nil
      return node if pointer.nil?

      resolve(pointer.delete_prefix("#/").split("/").reduce(document) { |target, key| target.fetch(key) }, document)
    end

    # One schema flattened for reading: references followed, `allOf` merged into
    # a single set of properties. Composition is how the document avoids saying
    # the same thing four times; it is not how anyone wants to read it.
    def expand(schema, document = source)
      schema = resolve(schema, document)
      return {} unless schema.is_a?(Hash)
      return schema unless schema.key?("allOf")

      schema.fetch("allOf").reduce(schema.except("allOf")) do |merged, part|
        part = expand(part, document)

        merged.merge(part) do |key, ours, theirs|
          case key
          when "properties" then ours.merge(theirs)
          when "required" then Array(ours) | Array(theirs)
          # The outer schema is the one that was written about this use of the
          # composed shape, so where both say something, it wins.
          else ours
          end
        end
      end
    end

    private

    def load_document
      YAML.safe_load_file(PATH)
    end
  end
end
