# frozen_string_literal: true

require "rails_helper"

# The contract is only worth anything if it cannot drift from the node it
# describes. Three things hold it in place:
#
#   1. this spec, which checks the document against the routes and against the
#      constants the code enforces;
#   2. spec/support/openapi_contract.rb, which checks every response the suite
#      produces against the shape the document promises;
#   3. CI, which runs both in each mode, so an endpoint that only exists on one
#      kind of node is checked on the kind of node that has it.
#
# Both directions matter. An endpoint missing from the document is a team
# integrating by reading source; an operation in the document with no route
# behind it is a team integrating against something that was never built.
RSpec.describe ApiContract do
  let(:document) { described_class.source }
  let(:operations) { described_class.operations }

  # Rails writes `/api/v3/orders/:tracking_number(.:format)`; the document
  # writes `/api/v3/orders/{tracking_number}`.
  def routed_operations
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.sub(/\(\.:format\)\z/, "")
      next unless path.start_with?(ApiContract::DOCUMENTED_PREFIX)

      verb = route.verb.presence || "GET"
      [ verb, path.gsub(/:(\w+)/) { "{#{Regexp.last_match(1)}}" } ]
    end.uniq
  end

  def operations_here
    operations.select { |operation| described_class.runs_here?(operation) }
  end

  describe "the document itself" do
    it "is OpenAPI 3.1" do
      expect(document["openapi"]).to start_with("3.1")
    end

    it "carries the version this node reports, so a stale contract is visible" do
      expect(document.dig("info", "version")).to eq(SislabSync.version)
    end

    it "says of every operation which kind of node answers it" do
      undeclared = operations.reject { |operation| operation.node_mode.in?(%w[local national both]) }

      expect(undeclared.map(&:to_s)).to be_empty
    end

    it "names every operation once" do
      ids = document.fetch("paths").values.flat_map do |item|
        item.slice(*ApiContract::VERBS).values.map { |definition| definition["operationId"] }
      end

      expect(ids).to all(be_present)
      expect(ids).to match_array(ids.uniq)
    end

    it "compiles every response schema it declares" do
      operations.each do |operation|
        operation.responses.each_key do |status|
          schema = OpenapiContract.response_schema(operation, status)
          expect(schema).to be_present, "#{operation} declares #{status} with no JSON schema"
        end
      end
    end

    it "resolves every reference it makes" do
      dangling = references(document).reject { |pointer| resolves?(pointer) }

      expect(dangling).to be_empty
    end
  end

  describe "the scopes it asks for" do
    it "are scopes a key can actually hold" do
      declared = operations.filter_map(&:scope).uniq

      expect(declared - ApiKey::SCOPES).to be_empty
    end

    it "lists the same set of scopes the model does" do
      expect(document.dig("components", "schemas", "Scope", "enum")).to match_array(ApiKey::SCOPES)
    end
  end

  # The enums are the part of a contract an integrator writes a case statement
  # against. A value the code can produce and the document does not list is a
  # client falling through to its else branch at a laboratory bench.
  describe "the vocabularies it publishes" do
    def enum_for(schema_name)
      document.dig("components", "schemas", schema_name, "enum")
    end

    it "lists every status an order can reach" do
      expect(enum_for("OrderStatus")).to match_array(Order.status_machine.statuses)
    end

    it "lists every status a test can reach" do
      expect(enum_for("TestStatus")).to match_array(OrderTest.status_machine.statuses)
    end

    it "lists every priority" do
      expect(enum_for("Priority")).to match_array(Order::PRIORITIES)
    end

    it "lists every dictionary entity" do
      expect(enum_for("DictionaryEntity")).to match_array(Dictionary::ENTITIES.keys)
    end

    it "lists every error code" do
      expect(enum_for("ErrorCode")).to match_array(Api::Errors::STATUSES.keys)
    end

    it "lists every event type that can cross between nodes" do
      expect(enum_for("SyncEventType")).to match_array(OutboxEvent::TYPES)
    end

    it "lists every state a referral can be in" do
      states = document.dig("components", "schemas", "Referral", "properties", "state", "enum")

      expect(states).to contain_exactly(Referral::DISPATCHED, Referral::RECEIVED, Referral::REJECTED)
    end
  end

  describe "against the routes this node draws" do
    it "documents every endpoint this node answers" do
      undocumented = routed_operations.reject do |verb, template|
        operations.any? { |operation| operation.verb == verb && operation.template == template }
      end

      expect(undocumented).to be_empty,
                              "not in #{OpenapiContract.relative_document_path}: " \
                              "#{undocumented.map { |verb, path| "#{verb} #{path}" }.join(', ')}"
    end

    it "has a route behind every operation it says this node answers" do
      routed = routed_operations
      missing = operations_here.reject { |operation| routed.include?([ operation.verb, operation.template ]) }

      expect(missing.map(&:to_s)).to be_empty
    end

    it "does not claim an endpoint the other kind of node keeps to itself" do
      routed = routed_operations
      elsewhere = operations.reject { |operation| described_class.runs_here?(operation) }
      leaked = elsewhere.select { |operation| routed.include?([ operation.verb, operation.template ]) }

      expect(leaked.map(&:to_s)).to be_empty
    end
  end

  # The error responses are the half of a contract that only gets read when
  # something is already wrong, which is exactly when a client cannot afford to
  # be guessing.
  describe "the failures it promises" do
    it "tells an authenticated operation how a bad key comes back" do
      authenticated = operations.select(&:authenticated?)
      silent = authenticated.reject { |operation| operation.responses.key?("401") }

      expect(silent.map(&:to_s)).to be_empty
    end

    it "tells every authenticated operation what a rate limit looks like" do
      authenticated = operations.select(&:authenticated?)
      silent = authenticated.reject { |operation| operation.responses.key?("429") }

      expect(silent.map(&:to_s)).to be_empty
    end
  end

  def references(node, found = [])
    case node
    when Hash
      found << node["$ref"] if node["$ref"].is_a?(String)
      node.each_value { |value| references(value, found) }
    when Array
      node.each { |value| references(value, found) }
    end

    found.uniq
  end

  def resolves?(pointer)
    return false unless pointer.start_with?("#/")

    pointer.delete_prefix("#/").split("/").reduce(document) do |target, key|
      return false unless target.is_a?(Hash) && target.key?(key)

      target.fetch(key)
    end

    true
  end
end
