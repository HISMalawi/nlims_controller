# frozen_string_literal: true

require 'sidekiq-unique-jobs'

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://localhost:6379/8' }
  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
  end

  SidekiqUniqueJobs::Server.configure(config)

  # Load sidekiq-cron schedule
  schedule_file = Rails.root.join('config', 'schedule.yml')
  if File.exist?(schedule_file)
    schedule = YAML.load_file(schedule_file)
    Sidekiq::Cron::Job.load_from_hash(schedule)
    Rails.logger.info('Sidekiq-cron schedule loaded successfully')
  else
    Rails.logger.warn('Sidekiq-cron schedule file not found')
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://localhost:6379/8' }
  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end
