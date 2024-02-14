recepient_types = %w[test_results_delivered_to_site_manually test_results_delivered_to_site_electronically
                     test_results_delivered_to_site_electronically_at_local_nlims_level]
puts 'loading recepient types--------------'
recepient_types.each do |type|
  chk = TestResultRecepientType.find_by(name: type)
  if !chk.blank?
    puts "#{type} already seeded"
  else
    tca = TestResultRecepientType.new
    tca.name = type
    tca.description = ''
    tca.save
    puts "#{type} seeded successfuly"
  end
end
