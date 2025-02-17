# frozen_string_literal: true

require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  mount Sidekiq::Web => '/sidekiq'
  root to: 'home#index'
  get 'latest_orders_by_site', to: 'home#latest_orders_by_site'
  get 'latest_results_by_site', to: 'home#latest_results_by_site'
  get 'search_orders', to: 'home#search_orders'
  get 'search_results', to: 'home#search_results'
  namespace :api do
    namespace :v1 do
      # order routes
      post '/create_order'	=> 'order#create_order'
      get  '/query_results_by_tracking_number/:tracking_number'	=> 'order#query_results_by_tracking_number'
      get '/query_order_by_tracking_number/:tracking_number'	=> 'order#query_order_by_tracking_number'
      get  '/query_order_by_npid/:npid'	=> 'order#query_order_by_npid'
      get  '/query_results_by_npid/:npid'	=> 'order#query_results_by_npid'
      post '/update_order'	=> 'order#update_order'
      get  '/query_requested_order_by_npid/:npid'	=> 'order#query_requested_order_by_npid'
      post '/dispatch_sample'	=> 'order#dispatch_sample'
      get	 '/check_if_dispatched/:tracking_number'	=> 'order#check_if_dispatched'
      get  '/retrieve_undispatched_samples'	=> 'order#retrieve_undispatched_samples'
      get  '/retrieve_samples/:order_date/:region'	=> 'order#retrieve_samples'

      # test routes
      post '/update_test' => 'test#update_test'
      post '/add_test' => 'test#add_test'
      put  '/edit_test_result' => 'test#edit_test_result'
      get  '/retrieve_test_Catelog'	=> 'test#retrieve_test_catelog'
      get	 '/query_test_measures/:test_name'	=> 'test#query_test_measures'
      get  '/query_test_status/:tracking_number'	=> 'test#query_test_status'
      get  '/query_tests_with_no_results_by_npid/:npid'	=> 'test#test_no_results'
      post '/acknowledge/test/results/recipient'	=> 'test#acknowledge_test_results_receiptient'

      # user routes
      post '/create_user'	=>	'user#create_user'
      get	 '/authenticate/:username/:password'	=>	'user#authenticate_user'
      get	 '/re_authenticate/:username/:password'	=>	'user#re_authenticate'
      get	 '/check_token_validity'	=>	'user#check_token_validity'

      # other routes
      get '/retrieve_order_location'	=> 'test#retrieve_order_location'
      get '/retrieve_target_labs'	=> 'test#retrieve_target_labs'

      # status of the app
      get '/ping' => 'status#ping'
      post '/register_order_source' => 'source_tracker#register_order_source'

      # Test Types
      get '/test_types' => 'test_type#index'
    end

    namespace :v2 do
      # order routes

      post '/request_order'	=> 'order#request_order'
      post '/confirm_order_request'	=> 'order#confirm_order_request'
      get  '/query_requested_order_by_npid/:npid'	=> 'order#query_requested_order_by_npid2'
      get '/query_order_by_tracking_number/:tracking_number'	=> 'order#query_order_by_tracking_number'
    end
  end
end
