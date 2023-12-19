# frozen_string_literal: true

new_test_types = [
  {
    name: 'Vdrl',
    short_name: 'Vdrl',
    specimens: ['Blood'],
    test_category: 'Microbiology',
    measures: [{ name: 'Vdrl', measure_type_id: 2 }]
  },
  {
    name: 'HIV-1 DNA PCR',
    short_name: 'HIV-1 DNA PCR',
    specimens: ['Blood','DBS', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)'],
    test_category: 'DNA/PCR',
    measures: [{ name: 'DNA', measure_type_id: 2 }]
  },
  {
    name: 'RBS',
    short_name: 'RBS',
    specimens: ['Blood'],
    test_category: 'Biochemistry',
    measures: [{ name: 'RBS', measure_type_id: 1 }]
  },
  {
    name: 'Urine chemistry (paeds)',
    short_name: '',
    specimens: ['Urine'],
    test_category: 'Paediatric Lab',
    measures: [
      { name: 'Blood', measure_type_id: 2 },
      { name: 'Urobilinogen', measure_type_id: 2 },
      { name: 'Bilirubin', measure_type_id: 2 },
      { name: 'Protein', measure_type_id: 2 },
      { name: 'Nitrate', measure_type_id: 2 },
      { name: 'Ketones', measure_type_id: 2 },
      { name: 'Glucose', measure_type_id: 2 },
      { name: 'Specific Gravity', measure_type_id: 2 },
      { name: 'Leucocytes', measure_type_id: 2 },
    ]
  },
  {
    name: 'Serum CrAg',
    short_name: 'Serum CrAg',
    specimens: ['Blood', 'Plasma'],
    test_category: 'Serology',
    measures: [{ name: 'Serum CrAg', measure_type_id: 4 }]
  },
  {
    name: 'CSF CrAg',
    short_name: 'CSF CrAg',
    specimens: ['CSF'],
    test_category: 'Serology',
    measures: [{ name: 'CSF CrAg', measure_type_id: 4 }]
  },
  {
    name: 'Malaria Screening (Paeds)',
    short_name: 'MalScr',
    specimens: ['Blood'],
    test_category: 'Paediatric Lab',
    measures: [
      { name: 'Blood film', measure_type_id: 2 },
      { name: 'Malaria species', measure_type_id: 2 },
      { name: 'MRDT', measure_type_id: 2 }
    ]
  },
  {
    name: 'Hepatitis B',
    short_name: 'HBV',
    specimens: ['Blood'],
    test_category: 'Immunochemistry',
    measures: [
      { name: 'HBV', measure_type_id: 4 }
    ]
  },
  {
    name: 'Hepatitis C',
    short_name: 'HCV',
    specimens: ['Blood'],
    test_category: 'Immunochemistry',
    measures: [
      { name: 'HCV', measure_type_id: 4 }
    ]
  },
  {
    name: 'Venereal disease research laboratory',
    short_name: 'Vdrl',
    specimens: ['Blood', 'Plasma'],
    test_category: 'Serology',
    measures: [
      { name: 'Vdrl', measure_type_id: 4 }
    ]
  }
]

new_test_types.each do |test_type|
  ActiveRecord::Base.transaction do 
    puts "Creating test type: #{test_type[:name]}"
    test_category = TestCategory.find_or_create_by!(name: test_type[:test_category])
    t = TestType.find_or_create_by!(
      test_category_id: test_category.id,
      name: test_type[:name],
      short_name: test_type[:short_name]
    )
    test_type[:specimens].each do | specimen_name |
      specimen = SpecimenType.find_or_create_by!(name: specimen_name)
      TesttypeSpecimentype.find_or_create_by!(
        test_type_id: t.id,
        specimen_type_id: specimen.id
      )
    end
    test_type[:measures].each do |m|
      measure = Measure.find_or_create_by!(
        name: m[:name],
        measure_type_id: m[:measure_type_id]
      )
      TesttypeMeasure.find_or_create_by!(test_type_id: t.id, measure_id: measure.id)
    end
  end
end
