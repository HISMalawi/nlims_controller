# frozen_string_literal: true

# Job to clean up stale lock files
class CleanupStaleLockJob
  include Sidekiq::Job
  sidekiq_options lock: :until_executed,
                  on_conflict: :log,
                  queue: :low_priority

  def perform
    Rails.logger.info('[CleanupStaleLockJob] Starting cleanup of stale locks')

    lock_dir = '/tmp'
    lock_files = [
      'log_tracking_numbers.lock',
      'sync_sh.lock',
      'nlims_sync_data.lock',
      'nlims_ack.lock',
      'nlims_update_couch_id.lock',
      'nlims_sync.lock',
      'nlims_sync_migrate.lock',
      'update_elasticsearch_index.lock'
    ]

    lock_files.each do |lock_file|
      lock_path = File.join(lock_dir, lock_file)
      if File.exist?(lock_path)
        File.delete(lock_path)
        Rails.logger.info("[CleanupStaleLockJob] Removed lock file: #{lock_path}")
      end
    rescue StandardError => e
      Rails.logger.error("[CleanupStaleLockJob] Error removing #{lock_path}: #{e.message}")
    end

    Rails.logger.info('[CleanupStaleLockJob] Completed cleanup of stale locks')
  rescue StandardError => e
    Rails.logger.error("[CleanupStaleLockJob] Error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
