# frozen_string_literal: true

##
# Worker for synchronizing test catalog from NLIMS
class TestCatalogSyncWorker
  def run
    return unless Config.local_nlims?

    Rails.logger.info('Starting test catalog synchronization')

    SyncToNlimsService.synchronize_test_catalog

    Rails.logger.info('Test catalog synchronization completed successfully')
  rescue StandardError => e
    Rails.logger.error("Error synchronizing test catalog: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
