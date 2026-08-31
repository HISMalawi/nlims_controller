# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /fhir/r4/metadata", mode: :local, type: :request do
  # Open, like /api-docs and for the same reason: it is what a team reads before
  # they have a key, and a contract you need credentials to read is one every
  # integrator will instead reconstruct by guessing.
  it "is readable without a key" do
    get "/fhir/r4/metadata"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/fhir+json")
    expect(response.parsed_body["resourceType"]).to eq("CapabilityStatement")
  end

  it "carries the version this node reports, so a stale contract is visible" do
    get "/fhir/r4/metadata"

    expect(response.parsed_body["version"]).to eq(SislabSync.version)
    expect(response.parsed_body["fhirVersion"]).to eq("4.0.1")
  end

  # Read off the router rather than a list written here: a list written here
  # only ever says that the statement matches what somebody once typed, and a
  # resource routed but undeclared is precisely what would slip past it.
  it "declares every resource the façade actually routes" do
    get "/fhir/r4/metadata"

    declared = response.parsed_body.dig("rest", 0, "resource").map { |resource| resource["type"] }

    expect(declared).to match_array(routed_resources)
  end

  # `/fhir/r4/ServiceRequest/:id` -> "ServiceRequest". `metadata` and the bare
  # base URL are the two paths that are not a resource.
  def routed_resources
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.sub(/\(\.:format\)\z/, "")
      segment = path.delete_prefix("/fhir/r4/").split("/").first
      next unless segment&.match?(/\A[A-Z]/)

      segment
    end.uniq
  end

  it "declares the transaction interaction and the acknowledge operation" do
    get "/fhir/r4/metadata"

    rest = response.parsed_body.dig("rest", 0)
    expect(rest["interaction"].map { |interaction| interaction["code"] }).to include("transaction")
    expect(rest["operation"].map { |operation| operation["name"] }).to include("acknowledge")
  end

  it "declares the search parameters the controllers read" do
    get "/fhir/r4/metadata"

    resources = response.parsed_body.dig("rest", 0, "resource").index_by { |resource| resource["type"] }

    expect(resources["Observation"]["searchParam"].map { |param| param["name"] }).to include("_since")
    expect(resources["ServiceRequest"]["searchParam"].map { |param| param["name"] }).to include("requisition")
  end
end
