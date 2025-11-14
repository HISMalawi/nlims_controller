# frozen_string_literal: true

puts 'Adding app_uuid to user'
User.all.each do |user|
  next if user&.app_uuid.present?

  user.update(app_uuid: SecureRandom.uuid)
end
