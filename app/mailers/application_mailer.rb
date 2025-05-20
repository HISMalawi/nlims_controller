# frozen_string_literal: true

# ApplicationMailer
class ApplicationMailer < ActionMailer::Base
  default from: 'umbnetworkmonitor@pedaids.org'
  layout 'mailer'
end
