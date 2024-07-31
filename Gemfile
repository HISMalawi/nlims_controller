source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

ruby '3.2.0'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 7.1.0'

gem 'mime-types', '~> 3.3'

gem 'parallel'
gem 'ruby-progressbar'
# Use mysql as the database for Active Record
gem 'mysql2', '>= 0.3.18'
# Use Puma as the app server
gem 'puma', '>= 3.7'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
gem 'apipie-rails'
gem 'bcrypt', '>= 3.1.7'
# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem 'rack-cors'

gem 'rest-client', '~> 2.1'

gem 'couchrest_model', '>= 2.0.4'
gem 'passenger'
# gem 'socket.io-client-simple', path: '/home/hopgausi/code/hismalawi/nlims_controller/ruby-socket.io-client-simple'
gem 'socket.io-client-simple'
gem 'sucker_punch'
group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
end

group :development do
  gem 'listen', '>= 3.0.5'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '>= 2.0.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
