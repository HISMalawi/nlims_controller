# frozen_string_literal: true

# Add roles to users
users = User.all
users.each do |user|
  if user.username == 'admin'
    user.roles << Role.find_by(name: 'admin')
  elsif user.roles.empty?
    user.roles << Role.find_by(name: 'system')
  else
    puts "User #{user.username} already has roles"
  end
end
