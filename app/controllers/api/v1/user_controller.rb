# frozen_string_literal: true

# User controller for managing users
class API::V1::UserController < ApplicationController
  def index
    excluded_roles = %w[admin system]
    users = User
            .joins(:roles)
            .where.not(roles: { name: excluded_roles })
            .distinct
            .where.not(username: 'admin')
            .order(:username)
            .select(:id, :username, :app_name, :app_uuid, :location, :partner, :created_at, :disabled)

    render json: users
  end

  def show
    user = User.includes(:roles).find(params[:id])

    render json: user.as_json(
      only: %i[id username app_name app_uuid location partner created_at],
      include: {
        roles: { only: %i[id name] }
      }
    )
  end

  def create
    unless params[:location] && params[:app_name] && params[:password] && params[:username] && params[:partner]
      render json: { message: 'missing parameter, please check' }, status: 422 and return
    end

    status = UserService.check_user(params[:username])
    render json: { message: 'username already taken' }, status: 422 and return if status == true

    details = UserService.create_user(params)
    render json: { message: 'account created successfuly', data: details }, status: 200 and return
  end

  def update
    user = User.find(params[:id])
    user.update!(user_params)
    if params[:roles].present?
      role_names = params[:roles].map { |r| r[:name] }
      roles = Role.where(name: role_names)
      user.roles = roles
    end

    render json: user.as_json(
      only: %i[id username app_name app_uuid location partner created_at],
      include: { roles: { only: [:name] } }
    )
  end

  def check_username
    status = UserService.check_user(params[:username])
    if status == false
      render json: { message: 'username available' }, status: 200
    else
      render json: { message: 'username already taken, please choose another one' }, status: 422
    end
  end

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
              expiry_time: details[:expiry_time],
              roles: details[:roles]
            }
          }
        else
          response = {
            status: 401,
            error: true,
            message: 'can not create account',
            data: {}
          }
        end
      else
        response = {
          status: 401,
          error: true,
          message: 'username already taken',
          data: {}
        }
      end

    else
      response = {
        status: 401,
        error: true,
        message: 'missing parameter, please check',
        data: {}
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
                     data: {}
                   }
                 else
                   {
                     status: 401,
                     error: true,
                     message: 'token expired',
                     data: {}
                   }
                 end

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

  def re_authenticate
    if params[:username] && params[:password]
      details = UserService.re_authenticate(params[:username], params[:password])
      response = if details == false
                   {
                     status: 401,
                     error: true,
                     message: 'wrong password or username',
                     data: {}
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
        data: {}
      }
    end
    render(plain: response.to_json) && return
  end

  def login
    if params[:username] && params[:password]
      auth = UserService.re_authenticate(params[:username], params[:password])
      return render json: { message: 'Wrong username or password' }, status: 401 if auth == false

      user = User
             .includes(:roles)
             .where(username: params[:username])
             .select(:id, :username, :app_name, :app_uuid, :disabled, :location, :partner)
             .first

      return render json: { message: 'User disabled' }, status: 401 if user.disabled

      render json: {
        user: user.as_json(
          only: %i[id username app_name app_uuid disabled location partner],
          include: {
            roles: { only: [:name] }
          }
        ),
        data: {
          token: auth[:token],
          expiry_time: auth[:expiry_time]
        }
      }
    else
      render json: { message: 'Username or Password not provided' }, status: 401
    end
  end

  def roles
    render json: Role.all
  end

  def locations
    render json: Site.pluck(:district)&.compact&.map(&:capitalize)&.sort_by(&:downcase)&.uniq
  end

  def disable_enable_user
    user = User.find(params[:id])
    user.update(disabled: params[:disabled])
    render json: user
  end

  def refresh_token
    auth = UserService.refresh_token(params[:app_uuid])
    if auth == false
      render json: { message: 'refresh token failed' }, status: 401
    else
      render json: {
        user: User.where(app_uuid: params[:app_uuid]).select(:id, :username, :app_name, :app_uuid).first,
        data: { token: auth[:token], expiry_time: auth[:expiry_time] }
      }
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :app_name, :app_uuid, :location, :partner, :password)
  end
end
