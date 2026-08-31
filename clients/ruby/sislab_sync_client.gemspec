# frozen_string_literal: true

require_relative "lib/sislab_sync_client/version"

Gem::Specification.new do |spec|
  spec.name = "sislab_sync_client"
  spec.version = SislabSyncClient::VERSION
  spec.authors = [ "MISAU — Direcção de Informação para a Saúde" ]

  spec.summary = "Reference client for a SISLAB Sync node."
  spec.description = <<~TEXT
    The client an EMR, a SISLAB installation or another node uses to talk to a
    SISLAB Sync node: three profiles over one envelope, with cursor feeds,
    idempotent writes and one exception per refusal the node can give.
  TEXT
  spec.homepage = "https://github.com/MISAU-DIS/nlims_controller"
  spec.license = "MIT"

  spec.metadata = {
    "source_code_uri" => "https://github.com/MISAU-DIS/nlims_controller/tree/main/clients/ruby",
    "rubygems_mfa_required" => "true"
  }

  # Matches the node's own, so one Ruby serves both at a site that runs them
  # side by side.
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*.rb"] + %w[README.md]
  spec.require_paths = [ "lib" ]

  # None, deliberately. A bearer token, a GET and a POST do not need a
  # dependency, and a laboratory server with no route to rubygems can still
  # vendor this by copying lib/.
end
