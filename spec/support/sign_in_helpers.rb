# frozen_string_literal: true

# Interface specs go through the sign-in form rather than setting the cookie
# themselves. It is one extra request per spec, and it means the thing every
# other screen depends on is exercised by every other screen's spec.
module SignInHelpers
  def sign_in(user, password: "palavra-passe-boa")
    post session_path, params: { session: { email: user.email, password: password } }
    raise "sign-in failed for #{user.email}" unless response.redirect?

    user
  end

  def sign_in_as(*traits, **attributes)
    sign_in(create(:user, *traits, **attributes))
  end
end

RSpec.configure do |config|
  config.include SignInHelpers, type: :request
end
