# frozen_string_literal: true

# A stand-in for the national node's change feed, answering the way
# Api::V3::DictionaryController does: entries past the cursor, oldest first,
# with next_cursor and has_more. Lets the puller be tested without a second
# database or a network.
class RecordedFeed
  attr_reader :requests

  def initialize(entries)
    @entries = entries.map { |entry| entry.deep_stringify_keys }.sort_by { |entry| entry["revision"] }
    @requests = []
  end

  def get(_path, params = {})
    since = params[:since].to_i
    limit = params[:limit].to_i
    @requests << since

    page = @entries.select { |entry| entry["revision"] > since }.first(limit)
    next_cursor = page.last&.fetch("revision") || since

    {
      "data" => page,
      "meta" => {
        "next_cursor" => next_cursor,
        "has_more" => @entries.any? { |entry| entry["revision"] > next_cursor }
      }
    }
  end
end

# Always has more to give, so the run has to stop itself.
class EndlessFeed
  def get(_path, params = {})
    since = params[:since].to_i

    {
      "data" => [ { "entity" => "drugs", "uuid" => SecureRandom.uuid,
                    "national_code" => "MOZ-DR-#{since + 1}", "name" => "Fármaco #{since + 1}",
                    "status" => "active", "revision" => since + 1 } ],
      "meta" => { "next_cursor" => since + 1, "has_more" => true }
    }
  end
end

class BrokenFeed
  def get(*)
    raise Dictionary::Puller::TransportError, "national node unreachable"
  end
end
