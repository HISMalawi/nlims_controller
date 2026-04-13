# frozen_string_literal: true

require 'logger'

##
# NLIMS Background Worker Module
# Manages multiple background workers for synchronization tasks
module NlimsWorker
  LOG_FILES_TO_KEEP = 5
  LOG_FILE_SIZE = 100.megabytes
  LOG_DIR = Rails.root.join('log', 'workers')

  def self.start(_start_date: nil)
    ensure_log_directory_exists

    puts "Starting NLIMS Workers at #{Time.now}"
    puts "Log directory: #{LOG_DIR}"

    # Fork workers for parallel execution
    # Each worker runs independently with its own lock
    fork { start_log_tracking_numbers_worker }
    fork { start_test_catalog_sync_worker }
    fork { start_push_orders_worker }
    fork { start_push_results_worker }
    fork { start_master_nlims_sync_data_worker }
    fork { start_push_acknowledgements_worker }

    # Wait for all child processes
    Process.waitall

    puts "All workers completed at #{Time.now}"
  end

  def self.start_log_tracking_numbers_worker
    start_worker('log_tracking_numbers_worker') do
      worker = LogTrackingNumbersWorker.new
      worker.run
    end
  end

  def self.start_test_catalog_sync_worker
    start_worker('test_catalog_sync_worker') do
      worker = TestCatalogSyncWorker.new
      worker.run
    end
  end

  def self.start_push_orders_worker
    start_worker('push_orders_worker') do
      worker = PushOrdersWorker.new
      worker.run
    end
  end

  def self.start_push_results_worker
    start_worker('push_results_worker') do
      worker = PushResultsWorker.new
      worker.run
    end
  end

  def self.start_push_acknowledgements_worker
    start_worker('push_acknowledgements_worker') do
      worker = PushAcknowledgementsWorker.new
      worker.run
    end
  end

  def self.start_sync_worker
    start_worker('sync_worker') do
      worker = SyncWorker.new
      worker.run
    end
  end

  def self.start_master_nlims_sync_data_worker
    start_worker('master_nlims_sync_data_worker') do
      worker = MasterNlimsSyncDataWorker.new
      worker.run
    end
  end

  # Removed: start_update_order_source_couch_id_worker
  # Now runs as a background job (UpdateOrderSourceCouchIdJob) weekly on Friday at 3pm

  def self.start_worker(worker_name)
    # Configure logger for this worker
    Rails.logger = file_logger(worker_name)
    ActiveRecord::Base.logger = Rails.logger
    Rails.logger.level = :info

    # Use file-based locking instead of flock
    lock_file_path = log_path("#{worker_name}.lock")

    File.open(lock_file_path, File::RDWR | File::CREAT, 0o644) do |fout|
      unless fout.flock(File::LOCK_EX | File::LOCK_NB)
        existing_pid = fout.read.to_s.strip
        Rails.logger.warn("Another process already holds lock for #{worker_name} (#{existing_pid}), exiting...")
        next
      end

      fout.truncate(0)
      fout.write("Locked by process ##{Process.pid} at #{Time.now}")
      fout.flush

      Rails.logger.info("Starting #{worker_name} (PID: #{Process.pid})")

      begin
        yield
      rescue StandardError => e
        Rails.logger.error("Error in #{worker_name}: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      ensure
        Rails.logger.info("#{worker_name} completed at #{Time.now}")
      end
    end
  end

  def self.file_logger(worker_name)
    Logger.new(log_path("#{worker_name}.log"), LOG_FILES_TO_KEEP, LOG_FILE_SIZE)
  end

  def self.log_path(filename)
    LOG_DIR.join(filename)
  end

  def self.ensure_log_directory_exists
    FileUtils.mkdir_p(LOG_DIR) unless Dir.exist?(LOG_DIR)
  end
end
