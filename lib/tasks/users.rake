# frozen_string_literal: true

# There is no self-service sign-up, and the first node to come up has nobody who
# can create an account through the interface. This is how the first one is made,
# and how a forgotten password is reset:
#
#   bin/rails "users:create[Ana Machava,ana@hcm.gov.mz,admin]"
#   bin/rails "users:reset_password[ana@hcm.gov.mz]"
#
# The password is generated and printed once, on the same principle as an API
# key: something typed in by whoever ran the command is something they already
# know, and usually something they have used elsewhere.
generated_password_length = 20

namespace :users do
  desc "Create a user for the interface: users:create[name,email,role]"
  task :create, %i[name email role] => :environment do |_task, args|
    name = args[:name].presence or abort("name is required: users:create[name,email,role]")
    email = args[:email].presence or abort("email is required: users:create[name,email,role]")
    role = args[:role].presence || User::OPERATOR

    password = SecureRandom.alphanumeric(generated_password_length)
    user = User.create!(name: name, email: email, role: role, password: password)

    puts "#{user.email} (#{user.role}) criado."
    puts "Palavra-passe: #{password}"
    puts "Anote-a agora — não volta a ser mostrada."
  end

  desc "Reset a user's password: users:reset_password[email]"
  task :reset_password, [ :email ] => :environment do |_task, args|
    user = User.find_by!(email: args[:email].to_s.strip.downcase)

    password = SecureRandom.alphanumeric(generated_password_length)
    user.update!(password: password)

    # Every browser they were signed in on stops working, which is the point of
    # resetting: the reason is usually that somebody else may have the old one.
    user.sessions.destroy_all

    puts "Palavra-passe de #{user.email} redefinida: #{password}"
    puts "Todas as sessões abertas foram terminadas."
  end

  desc "List the users of this node"
  task list: :environment do
    User.order(:email).find_each do |user|
      state = user.active? ? "activo" : "inactivo"
      seen = user.last_signed_in_at ? I18n.l(user.last_signed_in_at, format: :short) : "nunca"
      puts format("%-32s %-10s %-9s último acesso: %s", user.email, user.role, state, seen)
    end
  end
end
