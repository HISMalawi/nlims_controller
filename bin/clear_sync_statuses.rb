#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to efficiently process sync status records and clear Sidekiq queues
# Actions:
#   - Sync trackers: Marks as synced (preserves data for auditing)
#   - Error logs: Deletes permanently (no need for long-term storage)
#   - Sidekiq queues: Clears all queues (scheduled, retry, dead, enqueued, stats)
# Usage: ruby bin/clear_sync_statuses.rb [end_date] [batch_size]
# Example: ruby bin/clear_sync_statuses.rb 2024-12-31 10000
# Example: ruby bin/clear_sync_statuses.rb "3 months ago" 5000

require 'fileutils'
require File.expand_path('../config/environment', __dir__)
require 'sidekiq/api'

# Parse command line arguments
end_date_input = ARGV[0] || '3 months ago'
batch_size = (ARGV[1] || 10_000).to_i

# Parse the date
begin
  end_date = if end_date_input.match?(/^\d{4}-\d{2}-\d{2}/)
               Date.parse(end_date_input).end_of_day
             else
               eval("#{batch_size}.#{end_date_input}").to_datetime
             end
rescue StandardError => e
  puts "Error parsing date '#{end_date_input}': #{e.message}"
  puts "\nUsage: ruby bin/clear_sync_statuses.rb [end_date] [batch_size]"
  puts "  end_date: Date string (YYYY-MM-DD) or relative time (e.g., '3 months ago')"
  puts '  batch_size: Number of records to process per batch (default: 10000)'
  exit 1
end

puts '=' * 80
puts 'SYNC STATUS PROCESSING SCRIPT'
puts '=' * 80
puts "End Date: #{end_date}"
puts "Batch Size: #{batch_size}"
puts 'Actions:'
puts '  - Sync trackers: Marked as synced (data preserved)'
puts '  - Error logs: Deleted (data removed)'
puts '=' * 80
puts

# Configuration for sync tables
SYNC_TABLES = [
  {
    name: 'status_sync_trackers',
    model: StatusSyncTracker,
    description: 'Status Sync Tracker',
    sync_field: :sync_status
  },
  {
    name: 'order_sync_trackers',
    model: OrderSyncTracker,
    description: 'Order Sync Tracker',
    sync_field: :synced
  },
  {
    name: 'order_status_sync_trackers',
    model: OrderStatusSyncTracker,
    description: 'Order Status Sync Tracker',
    sync_field: :sync_status
  },
  {
    name: 'results_sync_trackers',
    model: ResultSyncTracker,
    description: 'Results Sync Tracker',
    sync_field: :sync_status
  },
  {
    name: 'added_test_sync_trackers',
    model: AddedTestSyncTracker,
    description: 'Added Test Sync Tracker',
    sync_field: :sync_status
  },
  {
    name: 'sync_error_logs',
    model: SyncErrorLog,
    description: 'Sync Error Log',
    action: :delete # Delete instead of marking
  }
].freeze

# Method to efficiently delete records in batches
def delete_in_batches(model, end_date, batch_size, _description)
  total_count = model.where('created_at <= ?', end_date).count

  if total_count.zero?
    puts '  ✓ No records to delete'
    return 0
  end

  puts "  Found #{total_count} records to delete"
  deleted_count = 0

  loop do
    # Delete in batches using limit to avoid long-running transactions
    deleted = model.where('created_at <= ?', end_date).limit(batch_size).delete_all

    break if deleted.zero?

    deleted_count += deleted
    progress = (deleted_count.to_f / total_count * 100).round(2)
    puts "  Progress: #{deleted_count}/#{total_count} (#{progress}%)"

    # Small sleep to avoid overwhelming the database
    sleep(0.1) if deleted >= batch_size
  end

  puts "  ✓ Deleted #{deleted_count} records"
  deleted_count
rescue StandardError => e
  puts "  ✗ Error: #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
  0
end

# Method to efficiently mark records as synced in batches
def mark_as_synced_in_batches(model, end_date, batch_size, _description, sync_field, additional_fields = {})
  # Count records that are not already synced
  total_count = model.where('created_at <= ?', end_date).where(sync_field => false).count

  if total_count.zero?
    puts '  ✓ No unsynced records to update'
    return 0
  end

  puts "  Found #{total_count} unsynced records to mark as synced"
  updated_count = 0

  # Prepare update attributes
  update_attrs = { sync_field => true }
  additional_fields.each do |field, value|
    update_attrs[field] = value.is_a?(Proc) ? value.call : value
  end

  loop do
    # Update in batches using limit to avoid long-running transactions
    updated = model.where('created_at <= ?', end_date)
                   .where(sync_field => false)
                   .limit(batch_size)
                   .update_all(update_attrs)

    break if updated.zero?

    updated_count += updated
    progress = (updated_count.to_f / total_count * 100).round(2)
    puts "  Progress: #{updated_count}/#{total_count} (#{progress}%)"

    # Small sleep to avoid overwhelming the database
    sleep(0.1) if updated >= batch_size
  end

  puts "  ✓ Marked #{updated_count} records as synced"
  updated_count
rescue StandardError => e
  puts "  ✗ Error: #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
  0
end

# Method to clear Sidekiq queues
def clear_sidekiq_queues
  puts "\n" + '=' * 80
  puts 'CLEARING SIDEKIQ QUEUES'
  puts '=' * 80
  puts

  cleared_counts = {}

  begin
    # Clear scheduled jobs
    scheduled = Sidekiq::ScheduledSet.new
    scheduled_count = scheduled.size
    scheduled.clear
    cleared_counts[:scheduled] = scheduled_count
    puts "  ✓ Cleared scheduled queue: #{scheduled_count} jobs"

    # Clear retry set
    retries = Sidekiq::RetrySet.new
    retry_count = retries.size
    retries.clear
    cleared_counts[:retries] = retry_count
    puts "  ✓ Cleared retry queue: #{retry_count} jobs"

    # Clear dead set
    dead = Sidekiq::DeadSet.new
    dead_count = dead.size
    dead.clear
    cleared_counts[:dead] = dead_count
    puts "  ✓ Cleared dead queue: #{dead_count} jobs"

    # Clear all queues (includes enqueued jobs)
    Sidekiq::Queue.all.each do |queue|
      queue_size = queue.size
      queue.clear
      cleared_counts[queue.name.to_sym] = queue_size
      puts "  ✓ Cleared '#{queue.name}' queue: #{queue_size} jobs"
    end

    # Clear stats (processed and failed counts)
    stats = Sidekiq::Stats.new
    processed_count = stats.processed
    failed_count = stats.failed

    # Reset stats by accessing Redis directly
    Sidekiq.redis do |conn|
      conn.del('stat:processed')
      conn.del('stat:failed')
    end
    cleared_counts[:processed_stats] = processed_count
    cleared_counts[:failed_stats] = failed_count
    puts "  ✓ Reset processed count: #{processed_count}"
    puts "  ✓ Reset failed count: #{failed_count}"

    # NOTE: 'busy' jobs are currently being processed and cannot be cleared
    busy_count = Sidekiq::Workers.new.size
    puts "  ℹ️  Currently busy jobs (cannot be cleared): #{busy_count}"
    cleared_counts[:busy_active] = busy_count

    puts
    puts 'Sidekiq queues cleared successfully!'
    cleared_counts
  rescue StandardError => e
    puts "  ✗ Error clearing Sidekiq queues: #{e.message}"
    puts "  Backtrace: #{e.backtrace.first(5).join("\n  ")}"
    {}
  end
end

# Main execution
puts "Starting sync status marking process...\n\n"

total_updated = 0
total_deleted = 0
start_time = Time.now

SYNC_TABLES.each do |table_config|
  puts "Processing: #{table_config[:description]} (#{table_config[:name]})"

  begin
    if table_config[:action] == :delete
      # Delete records for this table
      deleted = delete_in_batches(
        table_config[:model],
        end_date,
        batch_size,
        table_config[:description]
      )
      total_deleted += deleted
    else
      # Mark records as synced
      updated = mark_as_synced_in_batches(
        table_config[:model],
        end_date,
        batch_size,
        table_config[:description],
        table_config[:sync_field],
        table_config[:additional_fields] || {}
      )
      total_updated += updated
    end
  rescue NameError => e
    puts "  ⚠ Model not found: #{table_config[:model]} - Skipping"
  rescue StandardError => e
    puts "  ✗ Unexpected error: #{e.message}"
  end

  puts
end

end_time = Time.now
duration = (end_time - start_time).round(2)

puts '=' * 80
puts 'PROCESSING SUMMARY'
puts '=' * 80
puts "Total records marked as synced: #{total_updated}"
puts "Total records deleted: #{total_deleted}"
puts "Duration: #{duration} seconds"
puts "Completed at: #{end_time}"
puts '=' * 80

puts "\nℹ️  Sync tracker records are marked as synced (preserved for auditing)"
puts "ℹ️  Sync error logs are deleted (older than #{end_date.to_date})"

# Clear Sidekiq queues
sidekiq_cleared = clear_sidekiq_queues

# Final summary
puts "\n" + '=' * 80
puts 'FINAL SUMMARY'
puts '=' * 80
puts 'Sync Processing:'
puts "  - Records marked as synced: #{total_updated}"
puts "  - Records deleted: #{total_deleted}"
puts "  - Duration: #{duration} seconds"
puts
puts 'Sidekiq Queues Cleared:'
sidekiq_cleared.each do |queue_name, count|
  puts "  - #{queue_name}: #{count} jobs"
end
puts '=' * 80
puts "\n✅ All operations completed successfully!"
