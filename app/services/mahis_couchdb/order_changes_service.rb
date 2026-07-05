# frozen_string_literal: true

module MahisCouchdb
  # Processes CouchDB _changes entries and imports changed patient lab orders into NLiMS.
  class OrderChangesService
    attr_reader :client, :importer

    def initialize(client = Client.new, importer = nil)
      @client = client
      @importer = importer || OrderImporter.new(client)
    end

    def call
      return { enabled: false, imported: 0 } unless client.enabled?

      since = SyncState.last_sequence || client.config.initial_since
      changes = client.changes(since:)
      imported = Array.wrap(changes['results']).sum do |change|
        process_change(change)
      end
      SyncState.update_last_sequence!(changes['last_seq'])
      { enabled: true, imported:, last_seq: changes['last_seq'] }
    end

    def process_change(change)
      return 0 if change['deleted']

      doc = change['doc']
      return 0 unless doc.is_a?(Hash)
      return 0 if doc['_id'].to_s.start_with?('_design/')

      importer.import_patient_doc(doc)
    rescue StandardError => e
      Rails.logger.warn("Failed processing MaHIS CouchDB change #{change['id']}: #{e.message}")
      0
    end
  end
end
