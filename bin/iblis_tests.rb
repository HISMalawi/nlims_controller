new_test_types = []
test_types = Iblis.find_by_sql("SELECT * FROM test_types where name not in ('t', 'tt', 'try')")
test_types.each do |test_type|
  specimens = Iblis.find_by_sql("SELECT * FROM specimen_types WHERE id IN (SELECT specimen_type_id FROM testtype_specimentypes WHERE test_type_id = #{test_type.id})")
  test_category = Iblis.find_by_sql("SELECT * FROM test_categories WHERE id IN (SELECT test_category_id FROM test_types WHERE id = #{test_type.id})")
  measures = Iblis.find_by_sql("SELECT * FROM measures WHERE id IN (SELECT measure_id FROM testtype_measures WHERE test_type_id = #{test_type.id})")
  new_test_types << {
    name: test_type.name,
    short_name: test_type&.short_name,
    specimen: specimens.map(&:name),
    test_category: test_category&.first&.name,
    measures: measures.map { |m| { name: m.name, measure_type_id: 2 } }
  }
end

new_test_types.each do |test_type|
  next if test_type[:specimen].empty?

  ActiveRecord::Base.transaction do
    puts "Creating test type: #{test_type[:name]}"
    test_category = TestCategory.find_or_create_by!(name: test_type[:test_category])
    t = TestType.find_or_create_by!(
      test_category_id: test_category.id,
      name: test_type[:name],
      short_name: test_type[:short_name]
    )
    specimens = test_type[:specimen]
    specimens.each do |_specimen|
      sp = SpecimenType.find_or_create_by!(name: test_type[:specimen])
      TesttypeSpecimentype.find_or_create_by!(
        test_type_id: t.id,
        specimen_type_id: sp.id
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

