# frozen_string_literal: true

# Keys can only be read once, at issue time, so specs hold on to the token the
# same way a real integrator has to.
module ApiKeyHelpers
  def issue_key(api_client: nil, scopes: ApiKey::SCOPES, **attributes)
    api_client ||= create(:api_client)
    ApiKey.issue!(api_client: api_client, scopes: scopes, **attributes)
  end

  def auth_headers(token, extra = {})
    { "Authorization" => "Bearer #{token}" }.merge(extra)
  end
end

RSpec.configure do |config|
  config.include ApiKeyHelpers
end
