# frozen_string_literal: true

# IntegrationSytemStatusMailer
class IntegrationSytemStatusMailer < ApplicationMailer
  def integration_status_email(recipients)
    service = IntegrationStatusService.new
    @site_reports = service.collect_outdated_sync_sites

    # Generate CSV report
    csv_file_path = service.generate_csv_report(@site_reports)

    # Attach the CSV file to the email
    attachments["integration_status_report_#{Date.today}.csv"] = File.read(csv_file_path)

    mail(to: recipients, subject: 'NLIMS Integration System Status')

    # Clean up temporary file
    File.delete(csv_file_path) if File.exist?(csv_file_path)
  end
end
