# frozen_string_literal: true

# Service to interact with systemctl for checking the status of the services
class SystemctlService
  class << self
    def sidekiq_service_status
      output = `systemctl is-active nlims-sidekiq`.strip
      case output
      when 'active'
        'Running'
      when 'inactive'
        'Not running'
      when 'failed'
        'Failed'
      else
        'Unknown'
      end
    rescue StandardError => e
      "error: #{e.message}"
    end
  end
end
