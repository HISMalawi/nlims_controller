# frozen_string_literal: true

module Integration
  # Base for the integration setup pages on master NLIMS. These are browser pages, so they use a
  # cookie session (NLIMS admin users) and CSRF protection instead of the API token headers.
  class BaseController < ApplicationController
    ADMIN_ROLE = 'admin'
    SESSION_TTL = 2.hours

    skip_before_action :authenticate_request
    protect_from_forgery with: :exception
    before_action :require_master_nlims
    before_action :require_admin

    helper_method :current_admin, :notice_message

    def self.admin?(user)
      user.present? && !user.disabled && user.roles.exists?(name: ADMIN_ROLE)
    end

    private

    def current_admin
      return @current_admin if defined?(@current_admin)

      @current_admin = session_admin
    end

    def session_admin
      return nil if session[:integration_admin_id].blank?
      return nil if session[:integration_seen_at].to_i < SESSION_TTL.ago.to_i

      user = User.find_by(id: session[:integration_admin_id])
      return nil unless self.class.admin?(user)

      session[:integration_seen_at] = Time.now.to_i
      user
    end

    def require_admin
      return if current_admin

      if request.format.json?
        render json: { error: 'Login required' }, status: :unauthorized
      else
        session[:integration_return_to] = request.fullpath if request.get?
        redirect_to integration_login_path
      end
    end

    def require_master_nlims
      return unless Config.local_nlims?

      render plain: 'Integration setup is only available on master NLIMS', status: :forbidden
    end

    # Audit trail (paper_trail) records the logged-in admin
    def find_current_user
      current_admin
    end

    # The app is API-only, so there is no flash middleware; a one-shot session value does the same job
    def notify(message)
      session[:integration_notice] = message
    end

    def notice_message
      @notice_message ||= session.delete(:integration_notice)
    end
  end
end
