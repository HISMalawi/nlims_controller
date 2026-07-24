# frozen_string_literal: true

module MahisCouchdb
  # Stores the CouchDB _changes checkpoint in the existing configs table.
  class SyncState
    CONFIG_TYPE = 'mahis_couchdb_sync_state'

    def self.last_sequence
      record&.configs&.dig('last_seq')
    end

    def self.update_last_sequence!(sequence)
      return if sequence.blank?

      state = record || Config.new(config_type: CONFIG_TYPE, configs: {})
      configs = (state.configs || {}).with_indifferent_access
      configs[:last_seq] = sequence
      configs[:last_checked_at] = Time.current.iso8601
      state.configs = configs
      state.save!
    end

    def self.record
      Config.find_by(config_type: CONFIG_TYPE)
    end
  end
end
