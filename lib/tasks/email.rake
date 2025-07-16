# frozen_string_literal: true

namespace :email do
  desc 'TODO'
  task send_integration_status_email: :environment do
    puts "sending integration status email @ #{Time.now}"
    DailyIntegrationStatusEmailWorker.perform_async
  end
end
