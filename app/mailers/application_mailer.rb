# frozen_string_literal: true

# ApplicationMailer
class ApplicationMailer < ActionMailer::Base
  default from: ENV['NLIMS_EMAIL_ADDRESS']
  layout 'mailer'
end
