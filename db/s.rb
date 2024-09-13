# frozen_string_literal: true

puts 'creating default user account--------------'
User.create(
  password: BCrypt::Password.create('knock_knock'),
  username: 'admin',
  app_name: 'nlims',
  partner: 'api_admin',
  location: 'Lilongwe',
  token: 'xxxxxxx',
  token_expiry_time: '000000000'
)
puts '-------------done----------'
