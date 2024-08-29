# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :authenticate_request, except: %w[
    re_authenticate check_token_validity authenticate_user create_user dispatch_sample
  ]

  def authenticate_request
    token = request.headers['token']
    status = UserService.check_token(token)
    if token
      if status == false

        response = {
          status: 401,
          error: true,
          message: 'token expired',
          data: {

          }
        }

      else
        return status
      end
    else
      response = {
        status: 401,
        error: true,
        message: 'token not provided',
        data: {

        }
      }
    end
    render(plain: response.to_json) && return
  end

  def remote_host
    if params[:tracking_number].present?
      TrackingNumberHost.find_or_create_by(tracking_number: params[:tracking_number], host: request.remote_ip)
    end
  end
end
