# frozen_string_literal: true

namespace :emr do
  desc 'TODO'
  task create_user: :environment do
    puts 'creating user in emr'
    emr_sync_service = EmrSyncService.new(nil, service_type: 'account_creation')
    emr_sync_service.create_account_in_emr
  end
end
