dispatcher_types = ['delivering_samples_to_molecular_lab','delivering_samples_to_district_hub','delivering_results_to_facility','sample_dispatched_from_facility', 'pickup_sample_from_hub']


puts 'loading dispatcher types--------------'

dispatcher_types.each do |type|
   # tca = TestCategory.create(name: ca, description: '') 
    chk = SpecimenDispatchType.find_by(name: type)
    if !chk.blank?
        puts "#{type} already seeded"
    else
        tca = SpecimenDispatchType.new
        tca.name = type
        tca.description = ""
        tca.save()
        puts "#{type} seeded successfuly"
    end
end
