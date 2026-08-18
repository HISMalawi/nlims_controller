source "https://rubygems.org"

gem "rails", "~> 8.1.3", ">= 8.1.3.1"

# Database and cache
gem "mysql2", "~> 0.5"
gem "redis", ">= 5.0"

# Web
gem "propshaft"
gem "puma", ">= 5.0"
gem "rack-cors"

# Hotwire + Tailwind
gem "importmap-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "turbo-rails"

# Background work
gem "sidekiq", "~> 7.3"
gem "sidekiq-cron", "~> 2.0"
# Sidekiq 7 asks for connection_pool >= 2.3 with no upper bound, but 3.0 changed
# TimedStack#pop and its scheduler thread dies on boot. Hold it at 2.x until the
# app moves to Sidekiq 8.
gem "connection_pool", "~> 2.5"

# The operator interface signs people in with a password. API clients never do:
# they carry a key, and ApiKey hashes those itself.
gem "bcrypt", "~> 3.1"

# Leaves the default gems in Ruby 3.4. The quality report, the coverage report
# and the LOINC worksheets are all CSV, so this stops being a warning and starts
# being a boot failure the day the image's Ruby moves.
gem "csv"

# Configuration
gem "dotenv-rails"

# Portuguese for the validation and error messages Rails itself produces.
gem "rails-i18n", "~> 8.0"

# Interactive API Reference UI via Scalar
gem "scalar_ruby"

gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "factory_bot_rails"
  gem "rspec-rails", "~> 8.0"
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-rspec", require: false

  # The OpenAPI contract in docs/sislab-sync/openapi.yaml is checked against the
  # real routes and against the responses the suite produces. OpenAPI 3.1 uses
  # JSON Schema draft 2020-12, which is what this validates.
  gem "json_schemer", "~> 2.3"

  # The reference client, from this repository. It is here so the suite can
  # drive all three of its profiles against this node — a client that is only
  # ever tested against a mock of the node is a client that agrees with the mock.
  gem "sislab_sync_client", path: "clients/ruby"
end

group :development do
  gem "web-console"
end
