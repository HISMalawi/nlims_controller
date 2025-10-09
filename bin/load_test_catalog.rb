test_catalog = JSON.parse(File.read('test_catalog_version.json'))

test_types = [
  'CrAg', 'Creatine', 'GeneXpert', 'ALT', 'AST', 'Coagulation Assay', 'Enzymes', 'Measles', 'Transfusion Outcome', 'Rubella', 'Urine Lam'
]
test_types.each do |tt|
  TestType.where(name: tt).delete_all
end
TestType.find_by(name: "Renal Function Test")&.update(nlims_code: "NLIMS_TT_0033_MWI")

puts "Processing test catalog #{test_catalog['version']}"
ProcessTestCatalogService.process_test_catalog(test_catalog['catalog'].deep_symbolize_keys)
puts 'Test catalog processed'
