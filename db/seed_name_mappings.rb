# frozen_string_literal: true

test_types = TestType.all
test_types.each do |test_type|
  NameMapping.find_or_create_by(manually_created_name: test_type.name, actual_name: test_type.name)
end
test_name_mapping = {
  'PIMA CD4' => 'CD4',
  'Viral Load Gene X-per' => 'Viral Load',
  'Cr Ag' => 'Cryptococcus Antigen Test',
  'Cd4 Count' => 'CD4',
  'Gene Xpert' => 'TB Tests',
  'Cryptococcal Antigen' => 'Cryptococcus Antigen Test',
  'AFB sputum smear' => 'TB Microscopic Exam',
  'B-HCG' => 'Beta Human Chorionic Gonatropin',
  'Serum calcium' => 'calcium',
  'GeneXpert' => 'TB Tests',
  'FBS' => 'FBC',
  'Renal Function Tests' => 'Renal Function Test',
  'D/Coombs' => 'Direct Coombs Test',
  'creat' => 'Creatinine',
  'AAFB (3rd)' => 'TB Microscopic Exam',
  'Urine micro' => 'Urine Microscopy',
  'AAFB (1st)' => 'TB Microscopic Exam',
  'ASOT' => 'Anti Streptolysis O',
  'Blood C/S' => 'Culture & Sensitivity',
  'Cryptococcal Ag' => 'Cryptococcus Antigen Test',
  'Gene Xpert Viral' => 'Viral Load',
  'I/Ink' => 'India Ink',
  'C_S' => 'Culture & Sensitivity',
  'hep' => 'Hepatitis B Test',
  'Sickle' => 'Sickling Test',
  'Protein and Sugar' => 'Protein'
}

test_name_mapping.each do |manually_created_name, actual_name|
  NameMapping.find_or_create_by(manually_created_name: manually_created_name, actual_name: actual_name)
end
