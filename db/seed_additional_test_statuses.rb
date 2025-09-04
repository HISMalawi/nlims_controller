# frozen_string_literal: true

test_statuses = %w[test_on_repeat]

test_statuses.each do |status|
  puts "Seeding additional test status: #{status}"
  status = TestStatus.find_by(name: status)
  puts "#{status.name} already exists, skipping..." if status.present?
  next if status.present?

  TestStatus.find_or_create_by!(name: status)
end
