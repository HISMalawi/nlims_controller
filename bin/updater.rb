# frozen_string_literal: true

puts 'Adding app_uuid to user'
User.all.each do |user|
  user.update(app_uuid: SecureRandom.uuid)
end
