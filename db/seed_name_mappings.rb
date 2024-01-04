# frozen_string_literal: true

test_types = TestType.all
test_types.each do |test_type|
  NameMapping.find_or_create_by(manually_created_name: test_type.name, actual_name: test_type.name)
end

specimens = SpecimenType.all
specimens.each do |specimen|
  NameMapping.find_or_create_by(manually_created_name: specimen.name, actual_name: specimen.name)
end

panels = PanelType.all
panels.each do |panel|
  NameMapping.find_or_create_by(manually_created_name: panel.name, actual_name: panel.name)
end

wards = Ward.all
wards.each do |ward|
  NameMapping.find_or_create_by(manually_created_name: ward.name, actual_name: ward.name)
end
name_mappings = {
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
  'Protein and Sugar' => 'Protein',
  'Nasopharyngeal' => 'Nasopharyngeal swab',
  'SARS-CoV-2' => 'SARS Cov 2',
  'CREATINE (J)' => 'Creatine kinase',
  'Plasma (2)' => 'Plasma',
  'DBS 70 micro ltr' => 'DBS 70ml',
  'DBS 70ml (2)' => 'DBS 70ml',
  'Bwaila Hospital Martin Preuss Centre' => 'Bwaila Hospital',
  'Kawale Health Center' => 'Kawale Health Centre',
  'Mitundu Hospital' => 'Mitundu Rural Hospital',
  'Area 18 Health Center' => 'Area 18 Urban Health Centre',
  'Chileka (Lilongwe) Health Center' => 'Chileka Health Centre (Lilongwe)',
  'Kamuzu (KCH) Central Hospital' => 'Kamuzu Central Hospital',
  'Gateway' => 'Gateway Clinic (Blantyre)'
}

name_mappings.each do |manually_created_name, actual_name|
  NameMapping.find_or_create_by(manually_created_name: manually_created_name.strip, actual_name: actual_name.strip)
end
