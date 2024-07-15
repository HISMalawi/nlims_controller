# frozen_string_literal: true

require 'emr_sync_service'

namespace :emr do
  desc 'TODO'
  task create_user: :environment do
    puts 'creating user'
    emr_sync_service = EmrSyncService.new(service_type: 'account_creation')
    emr_sync_service.create_account_in_emr
  end
end
