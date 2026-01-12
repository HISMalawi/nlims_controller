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
  puts "Fixing #{measure[:names]} to #{measure[:code]}"
  Measure.where(name: measure[:names]).update_all(nlims_code: measure[:code])
end

puts 'Done'
