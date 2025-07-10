# frozen_string_literal: true

# DailyIntegrationStatusEmailWorker
class GenerateIntegrationStatusReportJob
  include Sidekiq::Job

  def perform
    return if Config.local_nlims?

    IntegrationStatusService.new.generate_status_report
  end
end
GenerateIntegrationStatusReportJob.perform_async
