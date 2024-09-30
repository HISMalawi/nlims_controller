# frozen_string_literal: true

namespace :master_nlims do
  desc 'Create an account in the master NLIMS system'
  task create_account: :environment do
    nlims = NlimsSyncUtilsService.new(nil, action_type: 'account_creation')
    nlims.create_account
  end
end
