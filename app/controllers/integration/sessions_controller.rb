# frozen_string_literal: true

module Integration
  # Login for the integration setup pages (NLIMS users with the admin role)
  class SessionsController < BaseController
    skip_before_action :require_admin

    def new
      redirect_to integration_sites_path if current_admin
    end

    def create
      user = User.find_by(username: params[:username].to_s)
      unless self.class.admin?(user) && valid_password?(params[:username], params[:password])
        @error = 'Invalid username/password, or the user is not an NLIMS admin'
        return render(:new, status: :unprocessable_entity)
      end

      return_to = session[:integration_return_to]
      reset_session
      session[:integration_admin_id] = user.id
      session[:integration_seen_at] = Time.now.to_i
      redirect_to safe_return_path(return_to)
    end

    def destroy
      reset_session
      redirect_to integration_login_path
    end

    private

    def valid_password?(username, password)
      password.present? && UserService.authenticate(username.to_s, password.to_s)
    rescue BCrypt::Errors::InvalidHash
      false
    end

    def safe_return_path(path)
      path.to_s.start_with?('/integration/') ? path : integration_sites_path
    end
  end
end
