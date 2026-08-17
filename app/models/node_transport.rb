# frozen_string_literal: true

require "net/http"

# How this node talks to another one.
#
# The local node always initiates, in both directions: it pulls the dictionary
# and it pushes its outbox. Laboratories sit behind NAT with no fixed address,
# so the national node could not reach them if it wanted to.
#
# Net::HTTP rather than a gem: a bearer token, a GET and a POST do not need one.
class NodeTransport
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 60

  class TransportError < StandardError; end

  def self.from_env(**options)
    new(
      base_url: ENV.fetch("SISLAB_SYNC_NATIONAL_URL", nil),
      api_key: ENV.fetch("SISLAB_SYNC_NATIONAL_API_KEY", nil),
      **options
    )
  end

  def initialize(base_url:, api_key:)
    raise TransportError, "SISLAB_SYNC_NATIONAL_URL is not set" if base_url.blank?
    raise TransportError, "SISLAB_SYNC_NATIONAL_API_KEY is not set" if api_key.blank?

    @base_uri = URI.parse(base_url)
    @api_key = api_key
  end

  def get(path, params = {})
    uri = build_uri(path)
    uri.query = URI.encode_www_form(params)

    parse(uri, perform(Net::HTTP::Get.new(uri), uri))
  end

  def post(path, body)
    uri = build_uri(path)

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    parse(uri, perform(request, uri))
  end

  private

  def build_uri(path)
    uri = @base_uri.dup
    uri.path = path
    uri
  end

  def parse(uri, response)
    unless response.is_a?(Net::HTTPSuccess)
      raise TransportError, "#{uri} answered #{response.code}: #{response.body.to_s.truncate(200)}"
    end

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise TransportError, "#{uri} did not answer with json: #{e.message}"
  end

  def perform(request, uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Accept"] = "application/json"

    Net::HTTP.start(uri.hostname, uri.port,
                    use_ssl: uri.scheme == "https",
                    open_timeout: OPEN_TIMEOUT,
                    read_timeout: READ_TIMEOUT) do |http|
      http.request(request)
    end
  rescue SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError => e
    raise TransportError, "#{uri} unreachable: #{e.class}: #{e.message}"
  end
end
