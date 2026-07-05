# frozen_string_literal: true

module MahisCouchdb
  # Runtime configuration for the MaHIS CouchDB integration.
  class Configuration
    DEFAULTS = {
      'enabled' => false,
      'protocol' => 'http',
      'host' => 'localhost',
      'port' => '5984',
      'path' => '',
      'database' => 'patients_records',
      'initial_since' => '0',
      'changes_limit' => 100,
      'timeout' => 30,
      'open_timeout' => 5,
      'read_timeout' => 65,
      'heartbeat' => 10_000,
      'reconnect_delay' => 5,
      'source_system' => 'mahis_couchdb'
    }.freeze

    attr_reader :settings

    def self.current
      app_config = load_application_config
      couch_config = app_config.fetch('mahis_couchdb', {})
      db_config = Config.configurations('mahis_couchdb') || {}
      env_config = {
        'enabled' => ENV['MAHIS_COUCHDB_ENABLED'],
        'protocol' => ENV['MAHIS_COUCHDB_PROTOCOL'],
        'host' => ENV['MAHIS_COUCHDB_HOST'],
        'port' => ENV['MAHIS_COUCHDB_PORT'],
        'path' => ENV['MAHIS_COUCHDB_PATH'],
        'database' => ENV['MAHIS_COUCHDB_DATABASE'],
        'username' => ENV['MAHIS_COUCHDB_USERNAME'],
        'password' => ENV['MAHIS_COUCHDB_PASSWORD'],
        'initial_since' => ENV['MAHIS_COUCHDB_INITIAL_SINCE'],
        'changes_limit' => ENV['MAHIS_COUCHDB_CHANGES_LIMIT'],
        'facility_name' => ENV['MAHIS_FACILITY_NAME'],
        'district' => ENV['MAHIS_DISTRICT']
      }.compact

      new(DEFAULTS.merge(app_config.slice('facility_name', 'district')).merge(couch_config).merge(db_config).merge(env_config))
    end

    def self.load_application_config
      path = Rails.root.join('config/application.yml')
      return {} unless File.exist?(path)

      YAML.load_file(path) || {}
    rescue StandardError => e
      Rails.logger.warn("Unable to load config/application.yml for MaHIS CouchDB integration: #{e.message}")
      {}
    end

    def initialize(settings)
      @settings = (settings || {}).with_indifferent_access
    end

    def enabled?
      ActiveModel::Type::Boolean.new.cast(settings[:enabled])
    end

    def base_url
      protocol = settings[:protocol].to_s.presence || 'http'
      host = settings[:host].to_s.presence || 'localhost'
      port = settings[:port].to_s.strip
      path = settings[:path].to_s.strip
      port_part = port.present? ? ":#{port}" : ''
      path_part = path.present? ? "/#{path.sub(%r{\A/+}, '').sub(%r{/+\z}, '')}" : ''

      "#{protocol}://#{host}#{port_part}#{path_part}"
    end

    def database
      settings[:database].presence || 'patients_records'
    end

    def username
      settings[:username].presence
    end

    def password
      settings[:password].presence
    end

    def initial_since
      settings[:initial_since].presence || '0'
    end

    def changes_limit
      settings[:changes_limit].to_i.positive? ? settings[:changes_limit].to_i : 100
    end

    def timeout
      settings[:timeout].to_i.positive? ? settings[:timeout].to_i : 30
    end

    def open_timeout
      settings[:open_timeout].to_i.positive? ? settings[:open_timeout].to_i : 5
    end

    def read_timeout
      settings[:read_timeout].to_i.positive? ? settings[:read_timeout].to_i : 65
    end

    def heartbeat
      settings[:heartbeat].to_i.positive? ? settings[:heartbeat].to_i : 10_000
    end

    def reconnect_delay
      settings[:reconnect_delay].to_i.positive? ? settings[:reconnect_delay].to_i : 5
    end

    def facility_name
      settings[:facility_name].presence || 'Unknown'
    end

    def district
      settings[:district].presence || 'Unknown'
    end

    def source_system
      settings[:source_system].presence || 'mahis_couchdb'
    end
  end
end
