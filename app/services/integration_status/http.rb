# frozen_string_literal: true

module IntegrationStatus
  # Thin RestClient wrapper shared by the checkers so timeouts and JSON parsing are handled the same way.
  module Http
    module_function

    def request_json(method:, url:, timeout:, payload: nil, headers: {}, verify_ssl: true)
      response = RestClient::Request.execute(
        method:,
        url:,
        payload: payload&.to_json,
        headers: { content_type: 'application/json', accept: 'application/json' }.merge(headers),
        timeout:,
        open_timeout: timeout,
        verify_ssl: verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      )
      JSON.parse(response.body)
    end
  end
end
