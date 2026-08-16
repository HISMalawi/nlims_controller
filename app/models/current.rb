# frozen_string_literal: true

# Per-request state. Set once by the authentication filter and read anywhere
# below it, so nothing has to thread the client through every call.
class Current < ActiveSupport::CurrentAttributes
  attribute :api_key, :api_client, :request_id, :ip

  def api_client
    super || api_key&.api_client
  end
end
