# frozen_string_literal: true

# Signing in and out of the operator interface.
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  # A shared bench machine is exactly where somebody would sit and guess. The
  # limit is per address rather than per IP because a whole laboratory arrives
  # from one address.
  rate_limit to: 10, within: 3.minutes, only: :create,
             by: -> { params.dig(:session, :email).to_s.downcase },
             with: -> { redirect_to new_session_path, alert: t("auth.too_many_attempts") }

  def new
    redirect_to root_path and return if signed_in?

    @email = params[:email]
  end

  def create
    user = User.authenticate(email: params.dig(:session, :email), password: params.dig(:session, :password))

    if user.nil?
      # Never says which half was wrong.
      @email = params.dig(:session, :email)
      flash.now[:alert] = t("auth.invalid_credentials")
      return render :new, status: :unprocessable_content
    end

    start_session_for(user)
    redirect_to after_sign_in_path, notice: t("auth.signed_in", name: user.name)
  end

  def destroy
    end_session
    redirect_to new_session_path, notice: t("auth.signed_out")
  end
end
