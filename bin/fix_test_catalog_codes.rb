# frozen_string_literal: true

measures_to_fix = [
  {
    names: ['UREA-H', 'Urea/Blood Urea Nitrogen'],
    code: 'NLIMS_TT_0128_MWI'
  },
  {
    names: %w[Glu Glucose],
    code: 'NLIMS_TT_0038_MWI'
  }
]

measures_to_fix.each do |measure|
  Measure.where(name: measure[:names]).update_all(test_catalog_code: measure[:code])
end
