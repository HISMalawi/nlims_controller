# puts 'creating default user account--------------'
# password_has = BCrypt::Password.create("knock_knock")
# username = 'admin'
# app_name = 'nlims'
# location = 'lilongwe'
# partner = 'api_admin'
# token = 'xxxxxxx'
# token_expiry_time = '000000000'

# User.create(password: password_has,
# 			username: username,
# 			app_name: app_name,
# 			partner: partner,
# 			location: location,
# 			token: token,
# 			token_expiry_time: token_expiry_time
# 		)

# puts '-------------done----------'
measure_types = {
  'Numeric' => {
    description: 'A numeric measurement type',
    structure: {
      type: 'ranges',
      parameters: [
        { name: 'Age Range', type: 'range', values: [{ min: 'number' }, { max: 'number' }] },
        { name: 'Measure Range', type: 'range', values: [{ min: 'number' }, { max: 'number' }] },
        { name: 'Interpretation', type: 'string', values: 'interpretation' },
        { name: 'Sex', type: 'options', values: %w[Male Female Both] }
      ]
    }
  },
  'Free Text' => {
    description: 'A freely entered text value',
    structure: {
      type: 'free_text'
    }
  },
  'AlphaNumeric' => {
    description: 'A combination of letters and numbers',
    structure: {
      type: 'options',
      parameters: [
        { name: 'value', type: 'string', values: 'value' },
        { name: 'Interpretation', type: 'string', values: 'interpretation' }
      ]
    }
  },
  'Rich Text' => {
    description: 'Formatted text with styling options',
    structure: {
      type: 'rich_text'
    }
  },
  'AutoComplete' => {
    description: 'A combination of letters and numbers',
    structure: {
      type: 'options',
      parameters: [
        { name: 'value', type: 'string', values: 'value' },
        { name: 'Interpretation', type: 'string', values: 'interpretation' }
      ]
    }
  }
}

measure_types.each do |name, attrs|
  MeasureType.find_or_create_by(name:).update(attrs)
end

def specimen
   MlabBase.find_by_sql('SELECT * FROM specimen').each do |specimen_mlab|
     specimen = SpecimenType.find_or_create_by!(
        name: specimen_mlab['name']
      )
        specimen.update_columns(
          description: specimen_mlab['description'],
          iblis_mapping_name: specimen_mlab['name'],
          preferred_name: specimen_mlab['name'],
          nlims_code: "NLIMS_SP_#{specimen.id.to_s.rjust(4, '0')}_MWI"
          )
   end
end

def test_panels
  MlabBase.find_by_sql("SELECT tp.* FROM test_panels tp WHERE tp.name NOT LIKE '%(cancer%'	AND tp.name NOT LIKE '%(paeds%'").each do |test_panel|
    test_types_panels = MlabBase.find_by_sql("SELECT tt.* FROM test_types tt INNER JOIN test_type_panel_mappings ttp ON ttp.test_type_id=tt.id WHERE ttp.test_panel_id=#{test_panel['id']}")
    t_panel = PanelType.find_or_create_by!(name: test_panel['name'])
    t_panel.update_columns(
      description: test_panel['description'],
      short_name: test_panel['short_name'],
      preferred_name: test_panel['name'],
      nlims_code: "NLIMS_TP_#{t_panel.id.to_s.rjust(4, '0')}_MWI"
    )
    t_panel.test_types = TestType.where(name: test_types_panels.pluck('name').uniq)
  end
end

def specimen_test_type_mappings(test_type_id, nlims_testtype)
  test_type_specimen = MlabBase.find_by_sql("
		SELECT s.* FROM specimen_test_type_mappings sptm INNER JOIN
		specimen s ON sptm.specimen_id=s.id WHERE test_type_id=#{test_type_id}
	")
  specimen_types = SpecimenType.where(name: test_type_specimen.pluck('name'))
  nlims_testtype.specimen_types = specimen_types
end

def test_types
  MlabBase.find_by_sql(
     "SELECT tt.*, et.value, et.unit FROM test_types tt INNER JOIN expected_tats et on et.test_type_id = tt.id
		 	WHERE tt.name NOT LIKE '%(cancer%'	AND tt.name NOT LIKE '%(paeds%' AND tt.name NOT IN
			('q', 'ss', 'cs', 'n', 'pll', 'fd', 'nn', 'lk', 'zz', 'll', 'try', 'tr', 'TT')"
   ).each do |test_type|
     nlims_testtype = TestType.find_by(name: test_type['name'])
     if test_type['name'] == 'GeneXpert'
       gx = TestType.where(name: 'GeneXpert')
       gx.last.delete if gx.count > 1
     end

     if nlims_testtype
           nlims_testtype.update_columns(
                  iblis_mapping_name: test_type['name'],
                  can_be_done_on_sex: test_type['sex'],
                  preferred_name: test_type['name'],
                  targetTAT: "#{test_type['value']} #{test_type['unit']}",
                  nlims_code: "NLIMS_TT_#{nlims_testtype.id.to_s.rjust(4, '0')}_MWI"
                )
     else
       department = MlabBase.find_by_sql("SELECT * FROM departments where id=#{test_type['department_id']}").first
       test_category_id = TestCategory.find_by(name: department['name'])&.id
       next unless test_category_id

       nlims_testtype = TestType.find_or_create_by!(
           name: test_type['name'],
           short_name: test_type['short_name'],
           targetTAT: "#{test_type['value']} #{test_type['unit']}",
           can_be_done_on_sex: test_type['sex'],
           iblis_mapping_name: test_type['name'],
           preferred_name: test_type['name'],
           test_category_id:
         )
     end
     measures(test_type['id'], nlims_testtype)
     specimen_test_type_mappings(test_type['id'], nlims_testtype)
     testtype_organism(test_type['id'], nlims_testtype)
   end
end

def drugs
  MlabBase.find_by_sql('SELECT * FROM drugs').each do |nlims_drug|
    drug = Drug.find_or_create_by!(name: nlims_drug['name'])
    drug.update_columns(
      description: nlims_drug['description'],
      short_name: nlims_drug['short_name'],
      preferred_name: nlims_drug['name'],
      nlims_code: "NLIMS_DRG_#{drug.id.to_s.rjust(4, '0')}_MWI"
      )
  end
end

def organisms
  MlabBase.find_by_sql(
     'SELECT * FROM organisms'
   ).each do |organism|
     nlims_organism = Organism.find_or_create_by!(name: organism['name'])
     nlims_organism.update_columns(
                   nlims_code: "NLIMS_ORG_#{nlims_organism.id.to_s.rjust(4, '0')}_MWI",
                   short_name: organism['short_name'],
                   description: organism['description'],
                   preferred_name: organism['name']
                 )

     organism_drug_mappings(organism['id'], nlims_organism)
   end
end

def organism_drug_mappings(organism_id, nlims_organism)
  drug_organims = MlabBase.find_by_sql("
		SELECT d.* FROM drug_organism_mappings drgo INNER JOIN
		drugs d ON drgo.drug_id=d.id WHERE organism_id=#{organism_id}
	")
  nlims_organism.drugs = Drug.where(name: drug_organims.pluck('name'))
end

def testtype_organism(test_type_id, nlims_testtype)
    testtype_organims = MlabBase.find_by_sql("
      SELECT o.* FROM test_type_organism_mappings ttom INNER JOIN
      organisms o ON ttom.organism_id=o.id WHERE test_type_id=#{test_type_id}
    ")
    nlims_testtype.organisms = Organism.where(name: testtype_organims.pluck('name'))
end

def measures(test_type_id, nlims_testtype)
  measures = MlabBase.find_by_sql("SELECT
      ti.id,
      ti.name,
      ti.unit,
      ti.description,
      tt.name AS test_name,
      CASE ti.test_indicator_type
          WHEN 0 THEN 'AutoComplete'
          WHEN 1 THEN 'Free Text'
          WHEN 2 THEN 'Numeric'
          WHEN 3 THEN 'AlphaNumeric'
          ELSE 'Rich Text'
      END AS test_indicator_type_name
  FROM
      test_indicators ti
          INNER JOIN test_type_indicator_mappings ttm
              ON ttm.test_indicators_id = ti.id
          INNER JOIN test_types tt
              ON tt.id = ttm.test_types_id
              AND tt.id = #{test_type_id} AND ti.name IS NOT NULL AND ti.name <>''")
    nlims_measures = []
    measures.each do |measure|
      m = Measure.find_by(name: measure['name'], unit: measure['unit'])
      if m.nil?
        m = Measure.create!(
          name: measure['name'],
          unit: measure['unit'],
          measure_type_id: MeasureType.find_by(name: measure['test_indicator_type_name']).id,
          description: measure['description'],
          iblis_mapping_name: measure['name'],
          preferred_name: measure['name']
        )
      end
      m.update_columns(
        unit: measure['unit'],
        nlims_code: m.nlims_code || "NLIMS_TI_#{m.id.to_s.rjust(4, '0')}_MWI",
        measure_type_id: MeasureType.find_by(name: measure['test_indicator_type_name']).id,
        description: measure['description'],
        iblis_mapping_name: measure['name'],
        preferred_name: measure['name']
      )
      nlims_measures << m.id
      measure_ranges(measure['id'], m)
    end
    nlims_testtype.measures = Measure.where(id: nlims_measures)
end

def measure_ranges(measure_id, nlims_measure)
  measure_ranges = MlabBase.find_by_sql("select * from test_indicator_ranges where test_indicator_id = #{measure_id}")
  nlims_measure_ranges = []
  measure_ranges.each do |measure_range|
    nlims_measure_range = MeasureRange.find_or_create_by!(
      measures_id: nlims_measure.id,
      age_min: measure_range['min_age'],
      age_max: measure_range['max_age'],
      sex: measure_range['sex'],
      range_lower: measure_range['lower_range'],
      range_upper: measure_range['upper_range'],
      interpretation: measure_range['interpretation'],
      value: measure_range['value']
    )
    nlims_measure_ranges << nlims_measure_range.id
  end
end

puts 'Importing specimen'
specimen
puts 'Importing test types'
test_types
puts 'Importing drugs'
drugs
puts 'Importing organisms'
organisms
puts 'Importing test panels'
test_panels
