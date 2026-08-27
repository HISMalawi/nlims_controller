# frozen_string_literal: true

# Issuing and revoking keys before the interface exists (S11), and afterwards
# for anything scripted.
#
#   NAME="EMR do HCM" KIND=emr bin/rails api_client:create
#   CLIENT="EMR do HCM" SCOPES="orders:write,results:read" bin/rails api_key:issue
#   KEY=a1b2c3d4 bin/rails api_key:revoke
#   bin/rails api_key:list
#
# On a local node the facility and laboratory codes are this node's own and
# need not be given: it is a laboratory, and it knows which. FACILITY_CODE and
# LAB_CODE are still read, for the national node, which issues keys on behalf
# of laboratories other than its own.

namespace :api_client do
  desc "Create an API client (NAME, KIND; FACILITY_CODE and LAB_CODE optional, taken from this node)"
  task create: :environment do
    client = ApiClient.create!(
      name: ENV.fetch("NAME"),
      kind: ENV.fetch("KIND"),
      facility_code: ENV["FACILITY_CODE"].presence,
      lab_code: ENV["LAB_CODE"].presence,
      notes: ENV["NOTES"].presence
    )

    puts "Client created"
    puts "  uuid           #{client.uuid}"
    puts "  name           #{client.name}"
    puts "  kind           #{client.kind}"
    puts "  facility_code  #{client.facility_code || '-'}"
    puts "  lab_code       #{client.lab_code || '-'}"
  end

  desc "List API clients"
  task list: :environment do
    ApiClient.order(:kind, :name).each do |client|
      state = client.active? ? "active" : "disabled"
      puts format("%-38s %-8s %-10s %-14s %s", client.uuid, client.kind, state,
                  client.facility_code || "-", client.name)
    end
  end
end

namespace :api_key do
  desc "Issue a key for a client (CLIENT=uuid|lab_code|facility_code|name, SCOPES=comma separated, EXPIRES_AT optional)"
  task issue: :environment do
    client = find_client!(ENV.fetch("CLIENT"))
    scopes = ENV.fetch("SCOPES").split(",").map(&:strip).reject(&:empty?)
    expires_at = ENV["EXPIRES_AT"].presence && Time.zone.parse(ENV["EXPIRES_AT"])

    key, token = ApiKey.issue!(
      api_client: client,
      scopes: scopes,
      expires_at: expires_at,
      issued_by: ENV["ISSUED_BY"].presence || ENV["USER"]
    )

    puts "Key issued for #{client.name} (#{client.kind})"
    puts "  uuid     #{key.uuid}"
    puts "  scopes   #{key.scopes.join(', ')}"
    puts "  expires  #{key.expires_at || 'never'}"
    puts
    puts "  #{token}"
    puts
    puts "This is the only time the token is shown. Store it now; it cannot be recovered."
  end

  desc "Revoke a key (KEY=uuid|prefix)"
  task revoke: :environment do
    identifier = ENV.fetch("KEY")
    key = ApiKey.find_by(uuid: identifier) || ApiKey.find_by(prefix: identifier)
    abort "No key matches #{identifier}" unless key

    key.revoke!
    puts "Revoked #{key.masked_token} (#{key.api_client.name}) at #{key.revoked_at}"
  end

  desc "List keys"
  task list: :environment do
    ApiKey.includes(:api_client).order(:created_at).each do |key|
      state = if key.revoked? then "revoked"
      elsif key.expired? then "expired"
      else "usable"
      end

      puts format("%-24s %-8s %-22s %-20s %s", key.masked_token, state, key.api_client.name,
                  key.last_used_at || "never used", key.scopes.join(","))
    end
  end
end

def find_client!(identifier)
  client = ApiClient.find_by(uuid: identifier) ||
           ApiClient.find_by(name: identifier) ||
           ApiClient.find_by(lab_code: identifier) ||
           ApiClient.find_by(facility_code: identifier)
  abort "No client matches #{identifier}" unless client

  client
end
