class ExpiredStockWriteOffNotificationJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  after_discard do |job, error|
    MailLogStatusCallbackJob.perform_later(
      job.arguments.fetch(2),
      job.arguments.fetch(3),
      job.arguments.fetch(4),
      'failed',
      error.message
    )
  end

  def perform(recipients, stock_transactions, mail_log_id, callback_base_url, callback_token)
    ExpiredStockWriteOffMailer
      .notification(recipients, stock_transactions)
      .deliver_now

    MailLogStatusCallbackJob.perform_later(
      mail_log_id,
      callback_base_url,
      callback_token,
      'sent'
    )
  end
end