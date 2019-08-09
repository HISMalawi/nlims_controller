require 'test_service.rb'
require 'user_service.rb'

class API::V1::TestController < ApplicationController


	def update_test
		update_details = params
		if update_details
			
				stat = status = TestService.update_test(params)
				if stat == true
						response = {
								status: 200,
								error: false,
								message: 'test updated successfuly',
								data: {
										
									}
							}
				else
						response = {
								status: 401,
								error: true,
								message: 'update failed',
								data: {
										
									}
							}

				end
		
		else
			response = {
					status: 401,
					error: true,
					message: 'update details not provided',
					data: {
						
					}
				}
			
		end
		render plain: response.to_json and return
	end

	def test_no_results
		npid = params[:npid]
		res = TestService.test_no_results(npid)

			if res[0] == true
				response = {	status: 200,
								error: false,
								message: 'test retrieved successfuly',
								data: res[1]
							}
			else
				response = {
								status: 401,
								error: true,
								message: 'no test pending for results',
								data: {
										
									}
							}
			end

			render plain: response.to_json and return
	end

	def query_test_status
		if params[:tracking_number]
			
			stat = status = TestService.query_test_status(params[:tracking_number])
			if stat[1] != false
					response = {
							status: 200,
							error: false,
							message: 'test measures retrieved successfuly',
							data: stat[1]
						}
			else
					response = {
							status: 401,
							error: true,
							message: 'no tests were ordered for the specimen',
							data: {
									
								}
						}

			end
	
		else
			response = {
					status: 401,
					error: true,
					message: 'tracking number not provided',
					data: {
						
					}
				}
			
		end


		render plain: response.to_json and return
	end

	def query_test_measures
		
		if params[:test_name]
			
				stat = status = TestService.query_test_measures(params[:test_name])
				if stat != false
						response = {
								status: 200,
								error: false,
								message: 'test measures retrieved successfuly',
								data: stat
							}
				else
						response = {
								status: 401,
								error: true,
								message: 'test measures retrievel failed',
								data: {
										
									}
							}

				end
		
		else
			response = {
					status: 401,
					error: true,
					message: 'test name not provided',
					data: {
						
					}
				}
			
		end


		render plain: response.to_json and return
	end

	def retrieve_order_location
		dat = TestService.retrieve_order_location
		if dat == false
			response = {
							status: 401,
							error: true,
							message: 'test catelog not available',
							data: {
										
							}
						}
		else
			response = {
							status: 200,
							error: false,
							message: 'test added successfuly',
							data: dat
						}
		end


		render plain: response.to_json and return
	end


	def retrieve_target_labs
		dat = TestService.retrieve_target_labs
		if dat == false
			response = {
							status: 401,
							error: true,
							message: 'test catelog not available',
							data: {
										
							}
						}
		else
			response = {
							status: 200,
							error: false,
							message: 'test added successfuly',
							data: dat
						}
		end


		render plain: response.to_json and return
	end

	def retrieve_test_catelog

		dat = TestService.retrieve_test_catelog
		if dat == false
			response = {
							status: 401,
							error: true,
							message: 'test catelog not available',
							data: {
										
							}
						}
		else
			response = {
							status: 200,
							error: false,
							message: 'test added successfuly',
							data: dat
						}
		end


		render plain: response.to_json and return
	end

	def add_test
		test_details = params
		if test_details
			
			res = TestService.add_test(params)
				if res == true
					response = {
								status: 200,
								error: false,
								message: 'test added successfuly',
								data: {
										
								}
							}
				else
					response = {
								status: 401,
								error: true,
								message: 'test add failed',
								data: {
										
								}
							}

				end
		else
			response = {
					status: 401,
					error: true,
					message: 'test details not provided',
					data: {
						
					}
				}
		end
		render plain: response.to_json and return

	end

	def edit_test_result
		test_details  = params
	
		if test_details			
			stat = TestService.edit_test_result(params)

					if stat == true
						response = {
								status: 200,
								error: false,
								message: 'test results edited successfuly',
								data: {
										
									}
							}
					else
						response = {
								status: 401,
								error: true,
								message: 'test result edit failed',
								data: {
										
									}
							}

					end
		else
			response = {
					status: 401,
					error: true,
					message: 'test result details not provided',
					data: {
						
					}
				}
		end
		render plain: response.to_json and return
	end

end
