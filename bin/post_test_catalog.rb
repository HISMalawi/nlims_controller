# frozen_string_literal: true

# Find tests with invalid test types
puts 'Finding tests with invalid test types'
tests_with_invalid_test_types = Test.left_joins(:test_type)
                                    .where(test_types: { id: nil })
                                    .select('tests.id, tests.test_type_id, test_types.name AS test_type_name', 'tests.specimen_id')
puts "Found #{tests_with_invalid_test_types.length} tests with invalid test types"
puts 'Finding orders with invalid tests'
orders_with_invalid_tests = Speciman.where(id: tests_with_invalid_test_types.pluck(:specimen_id))
puts "Found #{orders_with_invalid_tests.count} orders with invalid tests"
puts 'Finding tests with invalid orders'
test_with_invalid_orders = Test.where(specimen_id: orders_with_invalid_tests.pluck(:id))
puts "Found #{test_with_invalid_orders.count} tests with invalid orders"
puts 'Deleting test results'
TestResult.where(test_id: test_with_invalid_orders.pluck(:id)).delete_all
puts 'Deleting test status trails'
TestStatusTrail.where(test_id: test_with_invalid_orders.pluck(:id)).delete_all
puts 'Deleting specimen status trails'
SpecimenStatusTrail.where(specimen_id: orders_with_invalid_tests.pluck(:id)).delete_all
puts 'Deleting tests'
test_with_invalid_orders.delete_all
puts 'Deleting orders'
orders_with_invalid_tests.delete_all
puts 'All done'
