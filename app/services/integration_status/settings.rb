# frozen_string_literal: true

module IntegrationStatus
  # Tunables for integration status checks, stored in Config(config_type: 'integration_status')
  # and editable from the integration settings page. Missing keys fall back to DEFAULTS.
  class Settings
    CONFIG_TYPE = 'integration_status'
    DEFAULTS = {
      'vl_concept_id' => 856,
      'vl_concept_name' => 'HIV Viral Load',
      'summary_window_days' => 1,
      'stale_sync_hours' => 48,
      'http_timeout_seconds' => 10,
      'parallel_threads' => 8
    }.freeze
    INTEGER_KEYS = DEFAULTS.select { |_k, v| v.is_a?(Integer) }.keys.freeze

    DEFAULTS.each_key do |key|
      define_method(key) { @values[key] }
    end

    def self.load
      new(Config.configurations(CONFIG_TYPE) || {})
    end

    def self.save(params)
      values = DEFAULTS.keys.each_with_object({}) do |key, hash|
        value = params[key]
        next if value.blank?

        hash[key] = INTEGER_KEYS.include?(key) ? Integer(value) : value.to_s.strip
      end
      settings = new(values)
      errors = settings.validation_errors
      return [false, errors] if errors.any?

      config = Config.find_or_initialize_by(config_type: CONFIG_TYPE)
      config.update!(configs: settings.to_h)
      [true, []]
    rescue ArgumentError, TypeError
      [false, ['All numeric settings must be whole numbers']]
    end

    def initialize(values)
      @values = DEFAULTS.merge(values.to_h.stringify_keys.slice(*DEFAULTS.keys))
    end

    def to_h
      @values.dup
    end

    def concept
      { name: vl_concept_name, id: vl_concept_id }
    end

    def summary_start_date
      Date.today - summary_window_days.days
    end

    def summary_end_date
      Date.today
    end

    def validation_errors
      errors = []
      INTEGER_KEYS.each do |key|
        errors << "#{key.humanize} must be greater than 0" unless @values[key].to_i.positive?
      end
      errors << 'Parallel threads must be at most 32' if parallel_threads.to_i > 32
      errors << 'VL concept name is required' if vl_concept_name.blank?
      errors
    end
  end
end
