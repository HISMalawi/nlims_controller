# frozen_string_literal: true

# A stand-in for the national node's receiving end, answering the way
# Api::V3::Sync::EventsController does: every event_uuid accepted once, and a
# rejection for anything it has been told to refuse.
#
# It keeps what it was sent, so a spec can ask the questions that matter across
# an outage — did anything arrive twice, and did anything never arrive at all —
# without a second database or a network.
class RecordingNationalNode
  attr_reader :batches, :heartbeats

  def initialize(refuse: {})
    @refuse = refuse
    @received = {}
    @batches = []
    @heartbeats = []
    @offline = false
  end

  def offline!
    @offline = true
  end

  def online!
    @offline = false
  end

  def post(path, body)
    raise NodeTransport::TransportError, "national node unreachable" if @offline

    body = body.deep_stringify_keys

    return heartbeat(body) if path.end_with?("/heartbeat")

    events(body)
  end

  # Every event the node has ever been sent, including the ones it was sent more
  # than once.
  def deliveries
    @batches.flatten
  end

  def event_uuids
    deliveries.map { |event| event["event_uuid"] }
  end

  # In the order they were first accepted, which is the order the national node
  # would have applied them in.
  def accepted_in_order
    @received.keys
  end

  private

  def events(body)
    batch = Array(body["events"])
    @batches << batch

    accepted = []
    rejected = []

    batch.each do |event|
      uuid = event["event_uuid"]
      code = @refuse[uuid]

      if code
        rejected << { "event_uuid" => uuid, "code" => code, "message" => "refused by the spec" }
      else
        @received[uuid] ||= event
        accepted << uuid
      end
    end

    { "data" => { "accepted" => accepted, "rejected" => rejected }, "meta" => {} }
  end

  def heartbeat(body)
    @heartbeats << body

    { "data" => { "node_code" => body["node_code"], "dictionary_cursor" => 0 }, "meta" => {} }
  end
end
