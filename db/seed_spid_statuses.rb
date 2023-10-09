# frozen_string_literal: true

statuses = [
  {
    name: 'Not Distributed',
    description: 'The specimen identification has not been distributed to a site.'
  },
  {
    name: 'Distributed',
    description: 'The specimen identification has been distributed to a site.'
  },
  {
    name: 'Used',
    description: 'The specimen identification has been used for testing.'
  }
]
statuses.each do |status|
  puts "Creating SpecimenIdentificationStatus: #{status[:name]}"
  CsigStatus.find_or_create_by(name: status[:name], description: status[:description])
end
