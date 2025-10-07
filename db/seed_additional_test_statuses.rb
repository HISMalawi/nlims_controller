# frozen_string_literal: true

test_statuses = %w[pending started completed verified rejected test_on_repeat test-rejected voided
                   sample_accepted_at_hub sample_rejected_at_hub sample_intransit_to_ml sample_accepted_at_ml
                   sample_rejected_at_ml drawn]

test_statuses.each do |status|
  puts "Seeding additional test status: #{status}"
  status = TestStatus.find_by(name: status)
  puts "#{status.name} already exists, skipping..." if status.present?
  next if status.present?

  TestStatus.find_or_create_by!(name: status)
end

specimen_statuses = %w[specimen_collected specimen_rejected specimen_accepted sample_accepted_at_hub
                       sample_rejected_at_hub sample_accepted_at_ml sample_rejected_at_ml]
specimen_statuses.each do |status|
  puts "Seeding additional specimen status: #{status}"
  status = SpecimenStatus.find_by(name: status)
  puts "#{status.name} already exists, skipping..." if status.present?
  next if status.present?

  SpecimenStatus.find_or_create_by!(name: status)
end
