# frozen_string_literal: true

def can_be_converted_to_array?(string)
  result = JSON.parse(string)
  result.is_a?(Array)
  SpecimenType.where(name: string).delete_all
  if result.length > 1
    result.each do |r|
      SpecimenType.find_or_create_by(name: r)
    end
  else
    SpecimenType.find_or_create_by(name: result[0])
  end
rescue JSON::ParserError
  false
end

puts 'Adding app_uuid to user'
User.all.each do |user|
  user.update(app_uuid: SecureRandom.uuid)
end

SpecimenType.all.each do |specimen|
  can_be_converted_to_array?(specimen[:name])
end
