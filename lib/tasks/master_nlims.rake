# frozen_string_literal: true

namespace :master_nlims do
  desc 'Create an account in the master NLIMS system'
  task create_account: :environment do
    nlims = NlimsSyncUtilsService.new(nil, action_type: 'account_creation')
    nlims.create_account
  end

  task register_order_source: :environment do
    TestService.vl_without_results.each do |test|
      puts "Registering order source for #{test['tracking_number']}"
      mns = NlimsSyncUtilsService.new(nil)
      mns.register_order_source(test['tracking_number'])
    end
  end

  task update_order_source_couch_id: :environment do
    if Config.local_nlims?
      TestService.vl_without_results.each do |test|
        puts "Updating order source couch ID for #{test['tracking_number']}"
        mns = NlimsSyncUtilsService.new(nil)
        mns.update_order_source_couch_id(test['tracking_number'], test['sending_facility'], test['couch_id'])
      end
    end
  end
end
