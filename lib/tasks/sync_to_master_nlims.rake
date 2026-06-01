namespace :master_nlims do
  desc 'Sync data from master NLIMS (deprecated - use workers instead)'
  task sync_data: :environment do
    exit unless Config.local_nlims?

    warn '[DEPRECATED] This rake task is deprecated. Use the worker system instead: bin/rails runner bin/worker.rb'

    # For backward compatibility, instantiate and run the worker
    worker = MasterNlimsSyncDataWorker.new
    worker.run
  end

  desc 'Test NLIMS syncing status'
  task test_syncing: :environment do
    nlims_service = NlimsSyncUtilsService.new(nil)
    emr_service = EmrSyncService.new(nil)
    res = TestService.vl_without_results

    status = {
      local_nlims_data_available_for_syncing: res.present? ? 'Yes' : 'No',
      nlims_authenticate_with_emr: emr_service.token.present? ? 'Success' : 'Failed',
      nlims_authenticate_with_nlims_chsu: nlims_service.token.present? ? 'Success' : 'Failed'
    }
    puts status
  end

  desc 'Sync local NLIMS acknowledgements (deprecated - use workers instead)'
  task sync_local_nlims_acknowledge_results: :environment do
    exit unless Config.local_nlims?

    warn '[DEPRECATED] This rake task is deprecated. Use the worker system instead: bin/rails runner bin/worker.rb'

    # For backward compatibility, instantiate and run the worker
    worker = MasterNlimsAckWorker.new
    worker.run
  end
end
