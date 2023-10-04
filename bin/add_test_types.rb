# frozen_string_literal: true

new_test_types = [
  {
    name: 'Vdrl',
    short_name: 'Vdrl',
    specimen: 'Blood',
    test_category: 'Microbiology', # Department
    measures: [{ name: 'Vdrl', measure_type_id: 2 }]
  }
]

new_test_types.each do |test_type|
  # next if TestType.find_by(name: test_type[:name]).present?
  puts "Creating test type: #{test_type[:name]}"
  test_category = TestCategory.find_or_create_by!(name: test_type[:test_category])
  t = TestType.find_or_create_by!(
    test_category_id: test_category.id,
    name: test_type[:name],
    short_name: test_type[:short_name]
  )
  specimen = SpecimenType.find_or_create_by!(name: test_type[:specimen])
  TesttypeSpecimentype.find_or_create_by!(
    test_type_id: t.id,
    specimen_type_id: specimen.id
  )
  test_type[:measures].each do |m|
    measure = Measure.find_or_create_by!(
      name: m[:name],
      measure_type_id: m[:measure_type_id]
    )
    TesttypeMeasure.find_or_create_by!(test_type_id: t.id, measure_id: measure.id)
  end
end
