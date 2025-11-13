# frozen_string_literal: true

test_statuses = %w[pending started completed verified rejected test_on_repeat test-rejected voided
                   sample_accepted_at_hub sample_rejected_at_hub sample_intransit_to_ml sample_accepted_at_ml
                   sample_rejected_at_ml drawn]
test_phases = %w[pre_analytical analytical post_analytical]
test_phases.each do |phase|
  TestPhase.find_or_create_by!(name: phase)
end
test_statuses.each do |status|
  puts "Seeding additional test status: #{status}"
  record = TestStatus.find_by(name: status)
  puts "#{record.name} already exists, skipping..." if record.present?
  next if record.present?

  TestStatus.find_or_create_by!(name: status, test_phase_id: TestPhase.find_by(name: 'analytical').id)
end

specimen_statuses = %w[specimen_collected specimen_rejected specimen_accepted sample_accepted_at_hub
                       sample_rejected_at_hub sample_accepted_at_ml sample_rejected_at_ml]
specimen_statuses.each do |status|
  puts "Seeding additional specimen status: #{status}"
  record = SpecimenStatus.find_by(name: status)
  puts "#{record.name} already exists, skipping..." if record.present?
  next if record.present?

  SpecimenStatus.find_or_create_by!(name: status)
end
