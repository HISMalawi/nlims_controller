# frozen_string_literal: true

class MailLogStatusCallbackJob < ApplicationJob
    queue_as :default

    retry_on RestClient::Exception, wait: :polynomially_longer, attempts: 5

    def perform(mail_log_id, callback_base_url, callback_token, status, error_message = nil)
      url = "#{callback_base_url.delete_suffix('/')}/mail_logs/#{mail_log_id}/delivery_status"

      RestClient::Request.execute(
        method: :post,
        url: url,
        payload: {
          status: status,
          delivered_at: Time.current.iso8601,
          error_message: error_message
        }.compact.to_json,
        headers: {
          content_type: :json,
          accept: :json,
          token: callback_token
        },
        timeout: 10,
        open_timeout: 10
      )
    end 
end