# frozen_string_literal: true

test_statuses = %w[test_on_repeat]

test_statuses.each do |status|
  puts "Seeding additional test status: #{status}"
  lab_status = TestStatus.find_by(name: status)
  puts "#{lab_status.name} already exists, skipping..." if lab_status.present?
  next if lab_status.present?

  TestStatus.find_or_create_by!(name: status)
end
