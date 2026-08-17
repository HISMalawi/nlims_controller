# frozen_string_literal: true

# A stand-in for the national node's inbound feed, answering the way
# Api::V3::Sync::InboundController does: deliveries past the cursor, oldest
# first, with next_cursor and has_more.
class RecordedInbound
  attr_reader :requests

  def initialize(events)
    @events = events.map(&:deep_stringify_keys).sort_by { |event| event["revision"] }
    @requests = []
  end

  def get(_path, params = {})
    since = params[:since].to_i
    limit = (params[:limit] || 100).to_i
    @requests << since

    page = @events.select { |event| event["revision"] > since }.first(limit)
    next_cursor = page.last&.fetch("revision") || since

    {
      "data" => page,
      "meta" => {
        "next_cursor" => next_cursor,
        "has_more" => @events.any? { |event| event["revision"] > next_cursor }
      }
    }
  end
end

class BrokenInbound
  def get(*)
    raise NodeTransport::TransportError, "national node unreachable"
  end
end
