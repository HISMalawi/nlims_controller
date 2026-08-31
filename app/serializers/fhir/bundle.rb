# frozen_string_literal: true

module Fhir
  # A set of resources as one answer.
  #
  # Paging is by `link`, as FHIR requires, and the cursor inside the next link is
  # a revision from a locked counter rather than a timestamp or an offset — the
  # same cursor the JSON results feed uses. That is what lets an EMR follow the
  # link until there is none and know it has missed nothing: an offset shifts
  # when a row is inserted behind it, and a timestamp can be overtaken by a
  # result that committed slowly.
  class Bundle
    SEARCHSET = "searchset"
    COLLECTION = "collection"
    TRANSACTION_RESPONSE = "transaction-response"

    def self.searchset(entries, base_url:, self_url: nil, next_url: nil, total: nil)
      new(type: SEARCHSET, entries: entries, base_url: base_url,
          self_url: self_url, next_url: next_url, total: total).as_json
    end

    # What a create answered with when it produced more than one resource — a
    # panel expanded into the tests the laboratory will actually run.
    def self.collection(entries, base_url:)
      new(type: COLLECTION, entries: entries, base_url: base_url).as_json
    end

    # The answer to a transaction. One entry per resource created, each saying
    # what happened to it and where it now lives, which is what a client needs
    # to record the identifiers it did not choose.
    def self.transaction_response(entries, base_url:)
      {
        resourceType: "Bundle",
        type: TRANSACTION_RESPONSE,
        entry: entries.map do |resource|
          {
            fullUrl: "#{base_url.to_s.chomp('/')}/#{resource[:resourceType]}/#{resource[:id]}",
            resource: resource,
            response: { status: "201 Created", location: "#{resource[:resourceType]}/#{resource[:id]}" }
          }
        end
      }
    end

    def initialize(type:, entries:, base_url:, self_url: nil, next_url: nil, total: nil)
      @type = type
      @entries = entries
      @base_url = base_url.to_s.chomp("/")
      @self_url = self_url
      @next_url = next_url
      @total = total
    end

    def as_json
      {
        resourceType: "Bundle",
        type: @type,
        # The count in this bundle when nothing else was said. A `total` that
        # means "matches in the whole search" would require a second count query
        # on every page, and the link chain already answers "is there more".
        total: @total || @entries.length,
        link: links.presence,
        entry: @entries.map { |resource| entry_for(resource) }
      }.compact
    end

    private

    def links
      [
        @self_url && { relation: "self", url: @self_url },
        @next_url && { relation: "next", url: @next_url }
      ].compact
    end

    def entry_for(resource)
      {
        fullUrl: "#{@base_url}/#{resource[:resourceType]}/#{resource[:id]}",
        resource: resource,
        search: { mode: "match" }
      }
    end
  end
end
