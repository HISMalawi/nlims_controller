#!/usr/bin/env ruby
# frozen_string_literal: true

# Helper script to investigate and manage mlab sync failures

require File.expand_path('../config/environment', __dir__)
require_relative 'mlab_to_nlims_sync'

class MlabSyncFailureManager
  def self.run
    loop do
      print_menu
      choice = gets.chomp

      case choice
      when '1'
        show_failure_summary
      when '2'
        show_failures_by_stage
      when '3'
        show_recent_failures
      when '4'
        search_by_tracking_number
      when '5'
        show_failure_details
      when '6'
        mark_failures_resolved
      when '7'
        export_failed_test_ids
      when '8'
        retry_specific_test
      when '9'
        retry_multiple_tests
      when '10'
        retry_failures_by_site
      when '11'
        puts 'Exiting...'
        break
      else
        puts 'Invalid choice. Please try again.'
      end

      puts "\nPress Enter to continue..."
      gets
    end
  end

  def self.print_menu
    system('clear') || system('cls')
    puts '=' * 80
    puts 'MLAB SYNC FAILURE MANAGER'
    puts '=' * 80
    puts ''
    puts '1. Show Failure Summary'
    puts '2. Show Failures by Stage'
    puts '3. Show Recent Failures (Last 50)'
    puts '4. Search by Tracking Number'
    puts '5. Show Failure Details'
    puts '6. Mark Failures as Resolved'
    puts '7. Export Failed Test IDs'
    puts '8. Retry Specific Test'
    puts '9. Retry Multiple Tests (Space-separated IDs)'
    puts '10. Retry All Failures by Site'
    puts '11. Exit'
    puts ''
    print 'Choose an option: '
  end

  def self.show_failure_summary
    puts "\n" + '=' * 80
    puts 'FAILURE SUMMARY'
    puts '=' * 80

    total = MlabSyncFailure.count
    unresolved = MlabSyncFailure.unresolved.count
    resolved = MlabSyncFailure.resolved.count

    puts "Total Failures: #{total}"
    puts "Unresolved: #{unresolved}"
    puts "Resolved: #{resolved}"
    puts ''

    return unless total > 0

    percentage_resolved = ((resolved.to_f / total) * 100).round(2)
    puts "Resolution Rate: #{percentage_resolved}%"
  end

  def self.show_failures_by_stage
    puts "\n" + '=' * 80
    puts 'FAILURES BY STAGE'
    puts '=' * 80

    stages = MlabSyncFailure.unresolved
                            .group(:failure_stage)
                            .count
                            .sort_by { |_, count| -count }

    if stages.empty?
      puts 'No unresolved failures!'
      return
    end

    puts format('%-30s %s', 'Stage', 'Count')
    puts '-' * 40
    stages.each do |stage, count|
      puts format('%-30s %d', stage, count)
    end

    # Also show by site
    puts "\n"
    puts format('%-30s %s', 'Site', 'Count')
    puts '-' * 40
    sites = MlabSyncFailure.unresolved
                           .group(:site_name)
                           .count
                           .sort_by { |_, count| -count }
    sites.each do |site, count|
      puts format('%-30s %d', site || 'Unknown', count)
    end
  end

  def self.show_recent_failures
    puts "\n" + '=' * 80
    puts 'RECENT FAILURES (Last 50)'
    puts '=' * 80

    failures = MlabSyncFailure.unresolved.recent.limit(50)

    if failures.empty?
      puts 'No unresolved failures!'
      return
    end

    puts format('%-6s %-15s %-20s %-20s %-25s %-50s', 'ID', 'Test ID', 'Tracking', 'Site', 'Stage', 'Reason')
    puts '-' * 140

    failures.each do |failure|
      reason = failure.failure_reason.truncate(50)
      puts format('%-6d %-15d %-20s %-20s %-25s %-50s',
                  failure.id,
                  failure.mlab_test_id,
                  failure.tracking_number&.truncate(20) || 'N/A',
                  failure.site_name&.truncate(20) || 'N/A',
                  failure.failure_stage,
                  reason)
    end

    puts "\nShowing #{failures.count} of #{MlabSyncFailure.unresolved.count} unresolved failures"
  end

  def self.search_by_tracking_number
    print "\nEnter tracking number: "
    tracking_number = gets.chomp

    failures = MlabSyncFailure.where('tracking_number LIKE ?', "%#{tracking_number}%")

    if failures.empty?
      puts "\nNo failures found for tracking number: #{tracking_number}"
      return
    end

    puts "\nFound #{failures.count} failure(s):"
    puts ''

    failures.each do |failure|
      puts '-' * 80
      puts "ID: #{failure.id}"
      puts "MLAB Test ID: #{failure.mlab_test_id}"
      puts "Tracking Number: #{failure.tracking_number}"
      puts "Site Name: #{failure.site_name}"
      puts "Test Type: #{failure.test_type_nlims_code}"
      puts "Stage: #{failure.failure_stage}"
      puts "Reason: #{failure.failure_reason}"
      puts "Resolved: #{failure.resolved ? 'Yes' : 'No'}"
      puts "Created: #{failure.created_at}"
      puts "Retry Count: #{failure.retry_count}"
    end
  end

  def self.show_failure_details
    print "\nEnter failure ID: "
    id = gets.chomp.to_i

    failure = MlabSyncFailure.find_by(id: id)

    if failure.nil?
      puts "\nFailure not found!"
      return
    end

    puts "\n" + '=' * 80
    puts 'FAILURE DETAILS'
    puts '=' * 80
    puts "ID: #{failure.id}"
    puts "MLAB Test ID: #{failure.mlab_test_id}"
    puts "Tracking Number: #{failure.tracking_number}"
    puts "Site Name: #{failure.site_name}"
    puts "Test Type (nlims_code): #{failure.test_type_nlims_code}"
    puts "Failure Stage: #{failure.failure_stage}"
    puts 'Failure Reason:'
    puts failure.failure_reason
    puts ''
    puts "Resolved: #{failure.resolved ? 'Yes' : 'No'}"
    if failure.resolved
      puts "Resolved At: #{failure.resolved_at}"
      puts "Resolved By: #{failure.resolved_by}"
      puts "Resolution Notes: #{failure.resolution_notes}"
    end
    puts ''
    puts "Retry Count: #{failure.retry_count}"
    puts "Last Retry: #{failure.last_retry_at}"
    puts "Created: #{failure.created_at}"
    puts ''

    return unless failure.payload_snapshot.present?

    puts 'Payload Snapshot:'
    puts '-' * 80
    begin
      payload = JSON.parse(failure.payload_snapshot)
      puts JSON.pretty_generate(payload)
    rescue JSON::ParserError
      puts failure.payload_snapshot
    end
  end

  def self.mark_failures_resolved
    puts "\nResolve failures:"
    puts '1. By ID'
    puts '2. By Stage'
    puts '3. By Reason (pattern match)'
    puts '4. By Site Name'
    print 'Choose: '
    choice = gets.chomp

    failures = case choice
               when '1'
                 print 'Enter failure ID: '
                 id = gets.chomp.to_i
                 [MlabSyncFailure.find_by(id: id)].compact
               when '2'
                 print 'Enter stage name: '
                 stage = gets.chomp
                 MlabSyncFailure.unresolved.where(failure_stage: stage)
               when '3'
                 print 'Enter reason pattern: '
                 pattern = gets.chomp
                 MlabSyncFailure.unresolved.where('failure_reason LIKE ?', "%#{pattern}%")
               when '4'
                 print 'Enter site name: '
                 site = gets.chomp
                 MlabSyncFailure.unresolved.where(site_name: site)
               else
                 puts 'Invalid choice'
                 return
               end

    if failures.empty?
      puts "\nNo failures found!"
      return
    end

    puts "\nFound #{failures.is_a?(ActiveRecord::Relation) ? failures.count : failures.length} failure(s)"
    print 'Enter resolution notes: '
    notes = gets.chomp

    print 'Mark as resolved by user ID: '
    user_id = gets.chomp

    print 'Confirm (yes/no): '
    confirm = gets.chomp.downcase

    if %w[yes y].include?(confirm)
      count = 0
      if failures.is_a?(ActiveRecord::Relation)
        failures.find_each do |failure|
          failure.mark_resolved!(user_id, notes)
          count += 1
        end
      else
        failures.each do |failure|
          failure&.mark_resolved!(user_id, notes)
          count += 1
        end
      end
      puts "\n#{count} failure(s) marked as resolved!"
    else
      puts "\nCancelled"
    end
  end

  def self.export_failed_test_ids
    print "\nExport to file (default: failed_test_ids.txt): "
    filename = gets.chomp
    filename = 'failed_test_ids.txt' if filename.empty?

    test_ids = MlabSyncFailure.unresolved.distinct.pluck(:mlab_test_id)

    File.write(filename, test_ids.join("\n"))
    puts "\nExported #{test_ids.count} test IDs to #{filename}"
  end

  def self.retry_specific_test
    print "\nEnter mlab test ID to retry: "
    test_id = gets.chomp.to_i

    # Check if test exists in mlab
    test = MlabTest.find_by(id: test_id)

    if test.nil?
      puts "\nTest not found in mlab database!"
      return
    end

    puts "\nFound test: ID #{test.id}"
    puts "Test Type: #{test.mlab_test_type&.name} (#{test.mlab_test_type&.nlims_code})"
    puts "Order: #{test.mlab_order&.tracking_number}"
    puts ''

    # Get default facility from MlabGlobal
    default_facility = MlabGlobal.current&.name

    print "Override sending facility [default: #{default_facility || 'from order data'}]: "
    facility = gets.chomp
    facility = nil if facility.empty?

    # Ask about timestamp adjustment
    puts "\n⚠ Some failures may be due to 'time update is in the past' errors."
    print 'Auto-adjust timestamps? (yes/no): '
    auto_adjust = gets.chomp.downcase
    auto_adjust_timestamps = %w[yes y].include?(auto_adjust)

    print 'Retry this test? (yes/no): '
    confirm = gets.chomp.downcase

    if %w[yes y].include?(confirm)
      puts "\nRetrying..."

      begin
        status, message = MlabToNlimsSyncService.quick_retry_test(
          test_id,
          sending_facility: facility,
          auto_adjust_timestamps: auto_adjust_timestamps
        )

        case status
        when :success
          puts "✓ Success! #{message}"
        when :skipped
          puts "→ Skipped: #{message}"
        when :failure
          puts "✗ Failed: #{message}"
        end
      rescue StandardError => e
        puts "Error: #{e.message}"
        puts e.backtrace.first(10)
      end
    else
      puts "\nCancelled"
    end
  end

  def self.retry_multiple_tests
    puts "\nEnter mlab test IDs to retry (space-separated, e.g., '123 456 789'):"
    print '> '
    input = gets.chomp

    # Parse the space-separated IDs
    test_ids = input.split.map(&:strip).map(&:to_i).reject(&:zero?)

    if test_ids.empty?
      puts "\nNo valid test IDs provided!"
      return
    end

    puts "\nFound #{test_ids.count} test ID(s) to retry: #{test_ids.join(', ')}"

    # Get default facility from MlabGlobal
    default_facility = MlabGlobal.current&.name

    print "\nOverride sending facility [default: #{default_facility || 'from order data'}]: "
    facility = gets.chomp
    facility = nil if facility.empty?

    # Ask about timestamp adjustment
    puts "\n⚠ Some failures may be due to 'time update is in the past' errors."
    print 'Auto-adjust timestamps? (yes/no): '
    auto_adjust = gets.chomp.downcase
    auto_adjust_timestamps = %w[yes y].include?(auto_adjust)

    print "\nRetry all #{test_ids.count} test(s)? (yes/no): "
    confirm = gets.chomp.downcase

    unless %w[yes y].include?(confirm)
      puts "\nCancelled"
      return
    end

    # Initialize counters
    success_count = 0
    failure_count = 0
    not_found_count = 0
    skipped_count = 0

    puts "\nProcessing #{test_ids.count} test(s)..."
    puts '=' * 80

    test_ids.each_with_index do |test_id, index|
      puts "\n[#{index + 1}/#{test_ids.count}] Processing Test ID #{test_id}..."

      # Check if test exists in mlab
      test = MlabTest.find_by(id: test_id)

      if test.nil?
        puts '  ⊘ Test not found in mlab database!'
        not_found_count += 1
        next
      end

      puts "  Test Type: #{test.mlab_test_type&.name} (#{test.mlab_test_type&.nlims_code})"
      puts "  Order: #{test.mlab_order&.tracking_number}"
      puts '  Retrying...'

      begin
        status, message = MlabToNlimsSyncService.quick_retry_test(
          test_id,
          sending_facility: facility,
          auto_adjust_timestamps: auto_adjust_timestamps
        )

        case status
        when :success
          puts "  ✓ Success! #{message}"
          success_count += 1
        when :skipped
          puts "  → Skipped: #{message}"
          skipped_count += 1
        when :failure
          puts "  ✗ Failed: #{message}"
          failure_count += 1
        end
      rescue StandardError => e
        puts "  ✗ Error: #{e.message}"
        puts "  #{e.backtrace.first}" if e.backtrace
        failure_count += 1
      end

      # Brief pause between tests to avoid overwhelming the system
      sleep(0.1) unless index == test_ids.count - 1
    end

    # Print summary
    puts "\n" + '=' * 80
    puts 'RETRY SUMMARY'
    puts '=' * 80
    puts "Total Requested: #{test_ids.count}"
    puts "Successes: #{success_count}"
    puts "Failures: #{failure_count}"
    puts "Not Found: #{not_found_count}"
    puts "Skipped: #{skipped_count}"
    if (success_count + failure_count + skipped_count) > 0
      success_rate = ((success_count.to_f / (success_count + failure_count + skipped_count)) * 100).round(2)
      puts "Success Rate: #{success_rate}%"
    end
    puts '=' * 80
  end

  def self.retry_failures_by_site
    puts "\n" + '=' * 80
    puts 'RETRY FAILURES BY SITE'
    puts '=' * 80

    # Get all sites with unresolved failures
    sites = MlabSyncFailure.unresolved
                           .group(:site_name)
                           .count
                           .sort_by { |_, count| -count }

    if sites.empty?
      puts "\nNo unresolved failures found!"
      return
    end

    puts "\nSites with unresolved failures:"
    puts format('%-5s %-40s %s', '#', 'Site Name', 'Count')
    puts '-' * 60
    sites.each_with_index do |(site, count), index|
      puts format('%-5d %-40s %d', index + 1, site || 'Unknown', count)
    end

    print "\nEnter site number (or 'all' for all sites): "
    choice = gets.chomp

    selected_sites = if choice.downcase == 'all'
                       sites.map { |site, _| site }
                     else
                       site_index = choice.to_i - 1
                       if site_index < 0 || site_index >= sites.length
                         puts "\nInvalid choice!"
                         return
                       end
                       [sites.to_a[site_index][0]]
                     end

    # Get default facility from MlabGlobal
    default_facility = MlabGlobal.current&.name

    print "\nOverride sending facility [default: #{default_facility || 'from order data'}]: "
    facility = gets.chomp
    facility = nil if facility.empty?

    # Ask about timestamp adjustment
    puts "\n⚠ Some failures may be due to 'time update is in the past' errors."
    puts 'Would you like to auto-adjust timestamps to fix these errors?'
    puts '(This will set test time_updated to be 1 hour after order creation date)'
    print 'Auto-adjust timestamps? (yes/no): '
    auto_adjust = gets.chomp.downcase
    auto_adjust_timestamps = %w[yes y].include?(auto_adjust)

    # Confirm before proceeding
    total_failures = MlabSyncFailure.unresolved.where(site_name: selected_sites).count
    puts "\nThis will retry #{total_failures} failure(s) from #{selected_sites.length} site(s)"
    puts "Timestamp adjustment: #{auto_adjust_timestamps ? 'ENABLED' : 'DISABLED'}"
    print 'Continue? (yes/no): '
    confirm = gets.chomp.downcase

    unless %w[yes y].include?(confirm)
      puts "\nCancelled"
      return
    end

    # Process each site
    selected_sites.each do |site_name|
      retry_site_failures(site_name, facility, auto_adjust_timestamps)
    end
  end

  def self.retry_site_failures(site_name, facility_override = nil, auto_adjust_timestamps = false)
    puts "\n" + '=' * 80
    puts "RETRYING FAILURES FOR: #{site_name || 'Unknown'}"
    puts '=' * 80

    failures = MlabSyncFailure.unresolved.where(site_name: site_name).order(:mlab_test_id)

    total = failures.count
    success_count = 0
    failure_count = 0
    skipped_count = 0

    puts "\nFound #{total} unresolved failure(s) to retry\n"

    failures.each_with_index do |failure, index|
      puts "\n[#{index + 1}/#{total}] Processing Test ID #{failure.mlab_test_id}..."

      # Check if test still exists
      test = MlabTest.find_by(id: failure.mlab_test_id)
      unless test
        puts '  ⊘ Test not found in mlab database - skipping'
        skipped_count += 1
        next
      end

      puts "  Test Type: #{test.mlab_test_type&.name} (#{test.mlab_test_type&.nlims_code})"
      puts "  Tracking: #{test.mlab_order&.tracking_number}"
      puts "  Previous failure: #{failure.failure_stage} - #{failure.failure_reason.truncate(60)}"
      puts '  Retrying...'

      begin
        # Use quick retry method for better performance
        status, message = MlabToNlimsSyncService.quick_retry_test(
          failure.mlab_test_id,
          sending_facility: facility_override,
          auto_adjust_timestamps: auto_adjust_timestamps
        )

        case status
        when :success
          puts "  ✓ #{message}"
          failure.mark_resolved!('system', 'Successfully retried via bulk site retry')
          success_count += 1
        when :skipped
          puts "  → Skipped: #{message}"
          skipped_count += 1
        when :failure
          puts "  ✗ Failed: #{message}"
          failure.increment!(:retry_count)
          failure.update(last_retry_at: Time.current)
          failure_count += 1
        end
      rescue StandardError => e
        puts "  ✗ Error: #{e.message}"
        failure.increment!(:retry_count)
        failure.update(last_retry_at: Time.current)
        failure_count += 1
      end

      # Brief pause to avoid overwhelming the database
      sleep(0.05) # Reduced from 0.1 since we're faster now
    end

    # Print summary for this site
    puts "\n" + '=' * 80
    puts "SUMMARY FOR #{site_name || 'Unknown'}"
    puts '=' * 80
    puts "Total Processed: #{total}"
    puts "Successes: #{success_count}"
    puts "Still Failing: #{failure_count}"
    puts "Skipped: #{skipped_count}"
    puts "Success Rate: #{total > 0 ? ((success_count.to_f / total) * 100).round(2) : 0}%"
    puts '=' * 80
  end
end

# Run the manager
MlabSyncFailureManager.run if $PROGRAM_NAME == __FILE__
