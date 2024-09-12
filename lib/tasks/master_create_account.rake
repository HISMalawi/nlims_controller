# frozen_string_literal: true

namespace :master_nlims do
  desc 'Create an account in the master NLIMS system'
  task create_account: :environment do
    config = YAML.load_file("#{Rails.root}/config/master_nlims.yml", aliases: true)
    username = config['username']
    password = config['password']
    protocol = config['protocol']
    port = config['port']
    default_username = config['default_username']
    default_password = config['default_password']
    location = config['location']

    reauth_url = "#{protocol}:#{port}/api/v1/authenticate/#{default_username}/#{default_password}"
    token = ''
    begin
      response = RestClient.get(
        reauth_url,
        content_type: 'application/json'
      )

      res = JSON.parse(response)
      token = res['data']['token'] if res['status'] == 200
      # Process the 'res' variable as needed
    rescue RestClient::ExceptionWithResponse => e
      # Handle exceptions here
      puts "Failed to create an account: #{e.message}"
    rescue StandardError => e
      # Handle other exceptions here
      puts "An error occurred: #{e.message}"
    end

    url = "#{protocol}:#{port}/api/v1/create_user"
    params = {
      username: username,
      password: password,
      partner: 'EGPAF',
      app_name: 'Local NLIMS',
      location: location
    }.to_json

    begin
      response = RestClient.post(
        url,
        params,
        content_type: 'application/json',
        token: token
      )

      user = JSON.parse(response)
      puts user
      # Process the 'user' variable as needed
    rescue RestClient::ExceptionWithResponse => e
      # Handle exceptions here
      puts "Failed to create an account: #{e.message}"
    rescue StandardError => e
      # Handle other exceptions here
      puts "An error occurred: #{e.message}"
    end
  end
end
