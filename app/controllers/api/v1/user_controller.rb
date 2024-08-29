# frozen_string_literal: true

require 'user_service.rb'

class API::V1::UserController < ApplicationController
  def create_user
    token = request.headers['token']
    if params[:location] && params[:app_name] && params[:password] && params[:username] && token && params[:partner]
      status = UserService.check_user(params[:username])
      if status == false
        st = UserService.check_account_creation_request(token)
        if st == true
          details = UserService.create_user(params)
          response = {
            status: 200,
            error: false,
            message: 'account created successfuly',
            data: {
              token: details[:token],
              expiry_time: details[:expiry_time]
            }
          }
        else
          response = {
            status: 401,
            error: true,
            message: 'can not create account',
            data: {

            }
          }
        end
      else
        response = {
          status: 401,
          error: true,
          message: 'username already taken',
          data: {

          }
        }
      end

    else
      response = {
        status: 401,
        error: true,
        message: 'missing parameter, please check',
        data: {

        }
      }
    end

    render(plain: response.to_json) && return
  end

  def authenticate_user
    if params[:username] && params[:password]
      status = UserService.authenticate(params[:username], params[:password])

      if status == true
        details = UserService.compute_expiry_time
        UserService.prepare_token_for_account_creation(details[:token])
        response = {
          status: 200,
          error: false,
          message: 'authenticated',
          data: {
            token: details[:token],
            expiry_time: details[:expiry_time]
          }
        }
      else
        response = {
          status: 401,
          error: true,
          message: 'not authenticated',
          data: {
            token: ''
          }
        }
      end
    else
      response = {
        status: 401,
        error: true,
        message: 'username or password not provided',
        data: {
          token: ''
        }
      }
    end

    render(plain: response.to_json) && return
  end

  def check_token_validity
    token = request.headers['token']
    if token
      status = UserService.check_token(token)
      response = if status == true
                   {
                     status: 200,
                     error: false,
                     message: 'token active',
                     data: {

                     }
                   }
                 else
                   {
                     status: 401,
                     error: true,
                     message: 'token expired',
                     data: {

                     }
                   }
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

  def re_authenticate
    if params[:username] && params[:password]
      details = UserService.re_authenticate(params[:username], params[:password])
      response = if details == false
                   {
                     status: 401,
                     error: true,
                     message: 'wrong password or username',
                     data: {

                     }
                   }
                 else
                   {
                     status: 200,
                     error: false,
                     message: 're authenticated successfuly',
                     data: {
                       token: details[:token],
                       expiry_time: details[:expiry_time]
                     }
                   }
                 end

    else
      response = {
        status: 401,
        error: true,
        message: 'password or username not provided',
        data: {

        }
      }
    end
    render(plain: response.to_json) && return
  end
end
