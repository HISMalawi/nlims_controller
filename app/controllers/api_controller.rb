class ApiController < ApplicationController
	require 'order_service.rb'
	require 'user_service.rb'
	require 'test_service.rb'

	def index

		render plain: {name: 'yes'} and return
	end


	def update_test
		update_details = params
		if update_details
			token = update_details[:token]
			status = UserService.check_token(token)

			if status == true
				status = TestService.update_test(params)
				
			else	
				response = {
					status: 401,
					error: true,
					message: 'token expired',
					data: {
						
					}
				}
			end
		else

			
		end
		render plain: response.to_json and return
	end


	def create_order
	
		if params[:token]

			status = UserService.check_token(params[:token])
			if status == true
				st = OrderService.create_order(params)
				if st == true
					response = {
						status: 200,
						error: false,
						message: 'order created successfuly',
						data: {
							tracking_number: 'XTRAK'
						}
					}
				end
			else	
				response = {
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
			

		render plain: response.to_json and return
	end


	def create_user

		if params[:location] && params[:app_name] && params[:password] && params[:username] && params[:token] && params[:partner]
			status = UserService.check_user(params[username])
			if status == false

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

		render plain: response.to_json and return
	end


	def authenticate_user

		if params[:username] && params[:password]
			status = UserService.authenticate(params[:username],params[:password])

			if (status == true)
				details = UserService.compute_expiry_time
			
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
						token: ""
					}
				}
			end
		else
			response = {
					status: 401,
					error: true,
					message: 'username or password not provided',
					data: {
						token: ""
					}
				}
		end

		render plain: response.to_json and return
	end



	def check_token_validity
		if params[:token]

			status = UserService.check_token(params[:token])
			if status == true
				response = {
					status: 200,
					error: false,
					message: 'token active',
					data: {
						
					}
				}
			else	
				response = {
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

		render plain: response.to_json and return
	end


	def re_authenticate
		if params[:username] && params[:password]
			details = UserService.re_authenticate(params[:username],params[:password])
			if details == false
				response = {
					status: 401,
					error: true,
					message: 'wrong password or username',
					data: {
						
					}
				}
			else
				response = {
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
		render plain: response.to_json and return
	end





end
