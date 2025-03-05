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
def specimen
   MlabBase.find_by_sql('SELECT * FROM specimen').each do |specimen|
     specimen = SpecimenType.find_or_create_by!(
        name: specimen['name']
      )
        specimen.update(description: specimen['description'], iblis_mapping_name: specimen['name'])
   end
end

def specimen_test_type_mappings(test_type_id, nlims_testtype)
  test_type_specimen = MlabBase.find_by_sql("
		SELECT s.* FROM specimen_test_type_mappings sptm INNER JOIN
		specimen s ON sptm.specimen_id=s.id WHERE test_type_id=#{test_type_id}
	")
  test_type_specimen.pluck('name').to_json if nlims_testtype.name == 'MRSA Test'
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
                  targetTAT: "#{test_type['value']} #{test_type['unit']}",
                  nlims_code: "NLIMS_TT#{nlims_testtype.id.to_s.rjust(4, '0')}_MWI"
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
           test_category_id:
         )
     end
     specimen_test_type_mappings(test_type['id'], nlims_testtype)
   end
end

specimen
test_types
