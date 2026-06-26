# frozen_string_literal: true

# This script is used to clear the sync trackers for all users. This is useful when you want to reset the sync state for all users, for example, after a major update or when you want to start fresh.

# Tests that are not VL tests

puts 'Clearing sync trackers for all users...'
puts 'This may take a while...'
puts 'Loading orders and tests to clear sync trackers for...'
if Config.local_nlims?
  VL_TEST_TYPE_NLIMS_CODE = 'NLIMS_TT_0071_MWI'
  test_type = TestType.find_by(nlims_code: VL_TEST_TYPE_NLIMS_CODE)
  tests = Test.where.not(test_type: test_type)
  orders = Speciman.where(id: tests.pluck(:specimen_id))

  puts "Found #{orders.count} orders to clear sync trackers for."
  puts 'Clearing sync trackers...'
  OrderSyncTracker.where(tracking_number: orders.pluck(:tracking_number)).update_all(synced: true)
  OrderStatusSyncTracker.where(tracking_number: orders.pluck(:tracking_number)).update_all(sync_status: true)
  StatusSyncTracker.where(tracking_number: orders.pluck(:tracking_number)).update_all(sync_status: true)
  ResultSyncTracker.where(tracking_number: orders.pluck(:tracking_number)).update_all(sync_status: true)
end
puts 'Sync trackers cleared for all users.'
puts 'Done.'

# Clear all Sidekiq jobs
puts "\nClearing all Sidekiq jobs..."

# Clear retry set
retry_set = Sidekiq::RetrySet.new
retry_count = retry_set.size
retry_set.clear
puts "Cleared #{retry_count} retries"

# Clear scheduled set
scheduled_set = Sidekiq::ScheduledSet.new
scheduled_count = scheduled_set.size
scheduled_set.clear
puts "Cleared #{scheduled_count} scheduled jobs"

# Clear dead set
dead_set = Sidekiq::DeadSet.new
dead_count = dead_set.size
dead_set.clear
puts "Cleared #{dead_count} dead jobs"

# Clear all queues (enqueued jobs)
queue_count = 0
Sidekiq::Queue.all.each do |queue|
  queue_count += queue.size
  queue.clear
end
puts "Cleared #{queue_count} enqueued jobs from all queues"

# Clear stats (processed and failed counters)
stats = Sidekiq::Stats.new
stats.reset
puts 'Reset processed and failed stats'