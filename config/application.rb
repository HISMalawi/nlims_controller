require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Defines SislabSync.mode / .local? / .national?. Required rather than
# autoloaded so the run mode is usable from initializers and config/routes.rb.
require_relative "sislab_sync"

module SislabSync
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Portuguese is the working language of every deployment; the locale files
    # exist so a second language stays possible without touching the views.
    config.i18n.default_locale = :pt
    config.i18n.available_locales = %i[pt en]
    config.i18n.fallbacks = [ :pt ]

    config.time_zone = "Africa/Maputo"
    config.active_record.default_timezone = :utc

    config.active_job.queue_adapter = :sidekiq

    config.api_only = false

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
