# frozen_string_literal: true

# DailyIntegrationStatusEmailWorker
class GenerateIntegrationStatusReportJob
  include Sidekiq::Job

  def perform
    IntegrationStatusService.new.generate_status_report
  end
end
GenerateIntegrationStatusReportJob.perform_async
