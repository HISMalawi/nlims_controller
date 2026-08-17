# frozen_string_literal: true

# Per-request state. Set once by the authentication filter and read anywhere
# below it, so nothing has to thread the client through every call.
class Current < ActiveSupport::CurrentAttributes
  attribute :api_key, :api_client, :request_id, :ip

  # Set while this node is applying somebody else's events. Changes made under
  # it produce no events of their own, or two nodes holding one sample would
  # push each other's news round in a circle for ever.
  attribute :replicating

  def api_client
    super || api_key&.api_client
  end
end
