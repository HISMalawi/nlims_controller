# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :authenticate_request, except: %w[
    re_authenticate check_token_validity authenticate_user create_user dispatch_sample
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
end
