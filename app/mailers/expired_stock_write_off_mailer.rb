# frozen_string_literal: true

class ExpiredStockWriteOffMailer < ApplicationMailer
  def notification(recipients, stock_transactions)
    @stock_transactions = stock_transactions

    mail(
      to: recipients,
      subject: "Expired stock write-off: #{stock_transactions.count} item(s)"
    )
  end
end