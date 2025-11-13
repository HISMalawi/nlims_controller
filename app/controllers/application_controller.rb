# frozen_string_literal: true

class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :authenticate_request, except: %w[
    re_authenticate check_token_validity authenticate_user create_user dispatch_sample authenticate_frontend_ui_service
    login refresh_token
  ]
  before_action :set_paper_trail_whodunnit

  def authenticate_request
    token = request.headers['token']
    status = UserService.check_token(token)
    if token
      return status unless status == false

      response = {
        status: 401,
        error: true,
        message: 'token expired',
        data: {}
      }

    else
      response = {
        status: 401,
        error: true,
        message: 'token not provided',
        data: {}
      }
    end
    render(plain: response.to_json) && return
  end

  def authenticate_frontend_ui_service
    token = request.headers['token']
    app_uuid = request.headers['appuuid']
    if app_uuid.present?
      user = User.find_by(app_uuid:)
      User.current = user if user.present?
      return user.present?
    end

    if token.present?
      status = UserService.check_token(token)
      if status == true
        user = User.find_by(token:)
        User.current = user if user.present?
        return true
      end

      render json: { message: 'Token expired' }, status: 401
    else
      render json: { message: 'token not provided' }, status: 401
    end
  end

  private

  def set_paper_trail_whodunnit
    user = find_current_user

    PaperTrail.request.whodunnit = user&.id
    # PaperTrail.request.controller_info = {
    #   ip: request.remote_ip,
    #   user_agent: request.user_agent,
    #   controller: controller_name,
    #   action: action_name
    # }
  end

  def find_current_user
    # Option 1: Use User.current if it's set by your authentication
    return User.current if User.current.present?

    # Option 2: Extract user from token directly
    token = request.headers['token']
    if token.present? && UserService.check_token(token) == true
      user = User.find_by(token: token)
      return user if user.present?
    end

    # Option 3: Use app_uuid if available
    app_uuid = request.headers['appuuid']
    if app_uuid.present?
      user = User.find_by(app_uuid: app_uuid)
      return user if user.present?
    end

    # Return nil for unauthenticated requests
    nil
  end
end
