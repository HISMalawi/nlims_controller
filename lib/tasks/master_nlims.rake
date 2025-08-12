# frozen_string_literal: true

namespace :master_nlims do
  desc 'Create an account in the master NLIMS system'
  task create_account: :environment do
    nlims = NlimsSyncUtilsService.new(nil, action_type: 'account_creation')
    nlims.create_account
  end

  task register_order_source: :environment do
    vl_without_results.each do |test|
      puts "Registering order source for #{test['tracking_number']}"
      mns = NlimsSyncUtilsService.new(nil)
      mns.register_order_source(test['tracking_number'])
    end
  end

  task update_order_source_couch_id: :environment do
    vl_without_results.each do |test|
      puts "Updating order source couch ID for #{test['tracking_number']}"
      mns = NlimsSyncUtilsService.new(nil)
      mns.update_order_source_couch_id(test['tracking_number'], test['sending_facility'], test['couch_id'])
    end
  end
end

def vl_without_results
  Test.find_by_sql("SELECT specimen.tracking_number as tracking_number, specimen.id as specimen_id,
    tests.id as test_id,test_type_id as test_type_id, test_types.name as test_name, specimen.couch_id as couch_id,
    specimen.sending_facility as sending_facility
    FROM tests INNER JOIN specimen ON specimen.id = tests.specimen_id
    INNER JOIN test_types ON test_types.id = tests.test_type_id
    WHERE tests.id NOT IN (SELECT test_id FROM test_results where test_id IS NOT NULL)
    AND DATE(specimen.date_created) > '2024-06-01' AND test_types.name LIKE '%Viral Load%'")
end
