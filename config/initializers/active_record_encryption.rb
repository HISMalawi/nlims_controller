# frozen_string_literal: true

# Keys for ActiveRecord encryption (used by EmrInstance#password).
# Rails credentials are used when present; otherwise the keys are read from ENV or from the
# `active_record_encryption` section of config/settings.yml. Generate keys with `bin/rails db:encryption:init`.
# Only set values that are found so we never override credentials with nil.
settings_path = Rails.root.join('config/settings.yml')
file_keys = begin
  File.exist?(settings_path) ? (YAML.load_file(settings_path)&.dig('active_record_encryption') || {}) : {}
rescue StandardError => e
  warn "Could not read active_record_encryption keys from settings.yml: #{e.message}"
  {}
end

%w[primary_key deterministic_key key_derivation_salt].each do |key|
  value = ENV["ACTIVE_RECORD_ENCRYPTION_#{key.upcase}"].presence || file_keys[key].presence
  Rails.application.config.active_record.encryption[key.to_sym] = value if value
end
