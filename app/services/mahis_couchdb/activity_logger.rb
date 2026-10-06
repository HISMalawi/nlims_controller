# frozen_string_literal: true

module MahisCouchdb
  # Sends MaHIS CouchDB integration activity to Rails logs and the listener console.
  module ActivityLogger
    private

    def log_info(message)
      log_activity(:info, message)
    end

    def log_warn(message)
      log_activity(:warn, message)
    end

    def log_error(message)
      log_activity(:error, message)
    end

    def log_activity(level, message)
      Rails.logger.public_send(level, message)
      $stdout.puts("#{Time.current.iso8601} #{level.to_s.upcase} #{message}")
      $stdout.flush
    rescue StandardError
      Rails.logger.public_send(level, message)
    end
  end
end
