# frozen_string_literal: true

# DailyIntegrationStatusEmailWorker
class DailyIntegrationStatusEmailWorker
  include Sidekiq::Worker

  def perform
    return if Config.local_nlims?

    IntegrationSytemStatusMailer.integration_status_email(
      Mailinglist.all.pluck(:email)
    ).deliver_now
  end
end
