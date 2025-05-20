# frozen_string_literal: true

# IntegrationSytemStatusMailer
class IntegrationSytemStatusMailer < ApplicationMailer
  def integration_status_email(recipients)
    @site_reports = IntegrationStatusService.new.collect_outdated_sync_sites
    mail(to: recipients, subject: 'NLIMS Integration System Status')
  end
end
