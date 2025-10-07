# frozen_string_literal: true

# Job for handling app check-ins
class AppCheckInJob
  include Sidekiq::Job

  def perform(site_id)
    nlims = NlimsSyncUtilsService.new(nil)
    RestClient::Request.execute(
      method: :post,
      url: "#{nlims.address}/api/v1/check_in",
      payload: { site_id: site_id }.to_json,
      headers: { content_type: 'application/json' },
      timeout: 10,
      open_timeout: 10
    )
  end
end
