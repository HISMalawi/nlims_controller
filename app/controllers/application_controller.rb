# frozen_string_literal: true

class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :authenticate_request, except: %w[
    re_authenticate check_token_validity authenticate_user create_user dispatch_sample authenticate_frontend_ui_service
    login refresh_token
  ]

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
end
