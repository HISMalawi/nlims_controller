# frozen_string_literal: true

# DailyIntegrationStatusEmailWorker
class GenerateIntegrationStatusReportJob
  include Sidekiq::Job
  sidekiq_options lock: :until_executed,
                  on_conflict: :reject

  def perform
    return if Config.local_nlims?

    IntegrationStatusService.new.generate_status_report
  end
end
GenerateIntegrationStatusReportJob.perform_async
