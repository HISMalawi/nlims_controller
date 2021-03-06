Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html


  namespace :api do
  	namespace :v1 do
  		#order routes
  		post '/create_order/:token'										 => 'order#create_order'
  		get  '/query_results_by_tracking_number/:tracking_number/:token' => 'order#query_results_by_tracking_number'
      get '/query_order_by_tracking_number/:tracking_number/:token'	 => 'order#query_order_by_tracking_number'
      get '/query_order_by_npid/:npid/:token' => 'order#query_order_by_npid'
      get '/query_sample_statistics' => 'order#samples_statistics'
      get '/query_sample_statistics/:sample_type/:test_type/:token' => 'order#samples_statistics_by_sample_type_by_test_type'
      get '/query_results_by_npid/:npid/:token' => 'order#query_results_by_npid'

  		#test routes
  		post '/update_test/:token'  				   					 => 'test#update_test'
      post '/add_test/:token'                           => 'test#add_test'
      put  '/edit_test_result/:token'                  => 'test#edit_test_result'
      get  '/get_order_test/:tracking_number'          => 'test#get_order_test'
 

  		#user routes	
  		post '/create_user/:token'						         		 =>	'user#create_user'
  		get	 '/authenticate/:username/:password' 				 		 =>	'user#authenticate_user'
  		get	 '/re_authenticate/:username/:password'						 =>	'user#re_authenticate'
  		get	 '/check_token_validity/:token' 							 =>	'user#check_token_validity'


  	end
  end

end
