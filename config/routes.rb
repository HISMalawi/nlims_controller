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
  get 'count_by_sending_facility', to: 'home#counts'
  get 'order_per_sending_facility', to: 'home#order_per_site'
  get 'sites_by_orders', to: 'home#sites_by_orders'
  get 'integrated_sites', to: 'home#integrated_sites'
  get '/refresh_app_ping_status' => 'home#refresh_app_ping_status'
  get '/orders_summary' => 'home#orders_summary'
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
      get  '/retrieve_samples/:order_date/:from_date/:region'	=> 'order#retrieve_samples'
      get 'get_order_tracking_numbers' => 'order#order_tracking_numbers_to_logged'
      get '/verify_order_tracking_number_exist/:tracking_number' => 'order#verify_order_tracking_number_exist'

      # test routes
      post '/update_test' => 'test#update_test'
      post '/add_test' => 'test#add_test'
      put  '/edit_test_result' => 'test#edit_test_result'
      get	 '/query_test_measures/:test_name'	=> 'test#query_test_measures'
      get  '/query_test_status/:tracking_number'	=> 'test#query_test_status'
      get  '/query_tests_with_no_results_by_npid/:npid'	=> 'test#test_no_results'
      post '/acknowledge/test/results/recipient'	=> 'test#acknowledge_test_results_receiptient'

      # user routes
      post '/create_user'	=>	'user#create_user'
      get	 '/authenticate/:username/:password'	=>	'user#authenticate_user'
      get	 '/re_authenticate/:username/:password'	=>	'user#re_authenticate'
      get	 '/check_token_validity'	=>	'user#check_token_validity'
      post '/login' => 'user#login'
      post '/refresh_token' => 'user#refresh_token'
      resources :users, controller: :user, only: %i[index create show update] do
        collection do
          get '/check_username/:username' => 'user#check_username'
        end
      end

      # other routes
      get '/retrieve_order_location'	=> 'test#retrieve_order_location'
      get '/retrieve_target_labs'	=> 'test#retrieve_target_labs'
      get '/sites' => 'test#sites'

      # status of the app
      get '/ping' => 'status#ping'
      post '/register_order_source' => 'source_tracker#register_order_source'
      post '/update_order_source_couch_id' => 'source_tracker#update_order_source_couch_id'

      resources :test_types, only: %i[index create show update destroy] do
        collection do
          get '/measures' => 'test_types#measures'
          get '/measure_types' => 'test_types#measure_types'
          post '/import' => 'test_types#import'
        end
      end

      # test catalog routes
      post '/approve_test_catalog' => 'test_types#approve_test_catalog'
      post '/release_test_catalog' => 'test_types#release_version'
      get  '/retrieve_test_catalog'	=> 'test_types#retrieve_test_catalog'
      get '/retrieve_test_catalog_versions' => 'test_types#retrieve_test_catalog_versions'
      get '/check_new_test_catalog_version_available' => 'test_types#new_test_catalog_version_available'

      resources :drugs
      resources :organisms
      resources :test_statuses
      resources :departments
      resources :specimen_types
      resources :lab_test_sites
      resources :equipments
      resources :products
      resources :test_panels
    end

    namespace :v2 do
      # order routes

      post '/request_order'	=> 'order#request_order'
      post '/confirm_order_request'	=> 'order#confirm_order_request'
      get  '/query_requested_order_by_npid/:npid'	=> 'order#query_requested_order_by_npid2'
      get '/query_order_by_tracking_number/:tracking_number'	=> 'order#query_order_by_tracking_number'
      post '/create_order'	=> 'order#create_order'
      post '/update_tests' => 'order#update_tests'
    end
  end
end
