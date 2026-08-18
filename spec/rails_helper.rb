# frozen_string_literal: true

require "spec_helper"
# Assigned, not defaulted with ||=. The development image pins
# RAILS_ENV=development, so `bundle exec rspec` inside the container would
# otherwise keep that value and run the whole suite against the node's working
# database — which is the very thing config/database.yml refuses to do.
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |file| require file }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.include FactoryBot::Syntax::Methods

  # For the specs that have to let an hour pass — backoff, staleness, an outage.
  config.include ActiveSupport::Testing::TimeHelpers

  # Belt and braces: a spec that travels without a block would otherwise leave
  # every spec after it running at the wrong time, and the failure would appear
  # somewhere else entirely.
  config.after { travel_back }

  config.filter_rails_from_backtrace!
end
