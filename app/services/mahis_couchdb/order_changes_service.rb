# frozen_string_literal: true

module MahisCouchdb
  # Processes CouchDB _changes entries and imports changed patient lab orders into NLiMS.
  class OrderChangesService
    include ActivityLogger

    PENDING_FLAG = 'has_pending_nlims_orders'
    STATUS_FIELD = 'nlims_order_listener_status'
    DEAD_LETTER_FIELD = 'nlims_order_listener_dead_letter'
    PROCESSABLE_STATUSES = [nil, '', 'pending', 'failed'].freeze
    BACKFILL_BATCH_SIZE = 100

    attr_reader :client, :importer

    def initialize(client = Client.new, importer = nil)
      @client = client
      @importer = importer || OrderImporter.new(client)
    end

    def call
      return { enabled: false, imported: 0 } unless client.enabled?

      process_all_pending_documents
    end

    def ensure_pending_index!
      client.create_index(
        fields: [PENDING_FLAG],
        name: 'has_pending_nlims_orders_idx',
        ddoc: 'has_pending_nlims_orders_idx'
      )
      log_info("[MaHIS CouchDB Orders] Ensured #{PENDING_FLAG} index")
    rescue StandardError => e
      log_warn("[MaHIS CouchDB Orders] Could not ensure #{PENDING_FLAG} index: #{e.message}")
    end

    def process_all_pending_documents(batch_size: BACKFILL_BATCH_SIZE)
      return { enabled: false, imported: 0, processed_docs: 0 } unless client.enabled?

      ensure_pending_index!
      imported = 0
      processed_docs = 0
      bookmark = nil

      loop do
        page = pending_documents_page(limit: batch_size, bookmark:)
        docs = Array.wrap(page['docs'])
        break if docs.empty?

        docs.each do |doc|
          imported += process_doc(doc)
          processed_docs += 1
        end

        next_bookmark = page['bookmark']
        break if next_bookmark.blank? || next_bookmark == bookmark

        bookmark = next_bookmark
      end

      log_info("[MaHIS CouchDB Orders] Pending order backfill finished processed_docs=#{processed_docs} imported=#{imported}")
      { enabled: true, imported:, processed_docs: }
    end

    def process_change(change)
      return 0 if change['deleted']

      doc = change['doc']
      return 0 unless doc.is_a?(Hash)
      return 0 if doc['_id'].to_s.start_with?('_design/')
      return 0 unless pending_nlims_order_doc?(doc)

      process_doc(doc)
    rescue StandardError => e
      log_warn("[MaHIS CouchDB Orders] Failed processing change #{change['id']}: #{e.message}")
      0
    end

    private

    def pending_documents_page(limit:, bookmark: nil)
      client.find({ PENDING_FLAG => true }, limit:, bookmark:)
    rescue StandardError => e
      log_warn("[MaHIS CouchDB Orders] Pending order _find failed: #{e.message}")
      {}
    end

    def process_doc(doc)
      importer.import_patient_doc(doc)
    end

    def pending_nlims_order_doc?(doc)
      return true if doc[PENDING_FLAG] == true

      lab_orders = doc['labOrders'] || doc[:labOrders] || {}
      orders = Array.wrap(lab_orders['unsaved'] || lab_orders[:unsaved]) + Array.wrap(lab_orders['saved'] || lab_orders[:saved])
      orders.any? do |order|
        order.is_a?(Hash) &&
          order[DEAD_LETTER_FIELD] != true &&
          PROCESSABLE_STATUSES.include?(order[STATUS_FIELD].to_s.presence)
      end
    end
  end
end
