# frozen_string_literal: true

module MahisCouchdb
  # Imports MaHIS patient-record lab orders into the local NLiMS database.
  class OrderImporter
    include ActivityLogger

    MAX_RETRY_ATTEMPTS = 3
    STATUS_FIELD = 'nlims_order_listener_status'
    RETRY_COUNT_FIELD = 'nlims_order_listener_retry_count'
    LAST_ERROR_FIELD = 'nlims_order_listener_last_error'
    FAILED_AT_FIELD = 'nlims_order_listener_failed_at'
    PROCESSED_AT_FIELD = 'nlims_order_listener_processed_at'
    DEAD_LETTER_FIELD = 'nlims_order_listener_dead_letter'
    PENDING_FLAG = 'has_pending_nlims_orders'
    DEAD_LETTER_FLAG = 'has_nlims_dead_letter_orders'
    PROCESSABLE_STATUSES = [nil, '', 'pending', 'failed'].freeze

    attr_reader :client, :log_errors

    def initialize(client = Client.new, log_errors: true)
      @client = client
      @log_errors = log_errors
    end

    def import_patient_doc(patient_doc)
      return 0 unless patient_doc.is_a?(Hash)

      imported = 0
      changed = false

      lab_orders(patient_doc).each do |order|
        next unless processable_order?(order)

        result = import_order(patient_doc, order)
        if %i[imported already_imported].include?(result)
          imported += 1 if result == :imported
          changed = true if mark_order_processed(order)
        else
          changed = true if mark_order_failed(order, @last_error)
        end
      end

      changed = refresh_patient_pending_flags(patient_doc) || changed
      persist_status_changes(patient_doc) if changed
      imported
    end

    private

    # Return the order hashes stored inside patient_doc directly, NOT copies.
    # Deep-copying here (the previous `.with_indifferent_access`) meant every
    # status mark from mark_order_processed/mark_order_failed was written to a
    # throwaway copy and never persisted, so the order stayed perpetually
    # "pending" and persist_status_changes rewrote the doc on every pass —
    # spinning CouchDB's continuous _changes feed in an endless loop.
    def lab_orders(patient_doc)
      lab_orders = patient_doc['labOrders'] || patient_doc[:labOrders] || {}
      Array.wrap(lab_orders['unsaved'] || lab_orders[:unsaved]) + Array.wrap(lab_orders['saved'] || lab_orders[:saved])
    end

    def processable_order?(order)
      return false unless order.is_a?(Hash)
      return false if order[DEAD_LETTER_FIELD] == true

      PROCESSABLE_STATUSES.include?(order[STATUS_FIELD].to_s.presence)
    end

    def import_order(patient_doc, order)
      @last_error = nil
      return fail_order('order payload missing') unless order.is_a?(Hash)

      mapper = LabOrderMapper.new(client.config, patient_doc, order)
      return fail_order('accession_number missing') if mapper.tracking_number.blank?

      unless mapper.valid?
        return fail_order(mapper.errors.join(', '), 'MaHIS CouchDB lab order skipped', patient_doc, order)
      end

      existing = Speciman.find_by(tracking_number: mapper.tracking_number) || Speciman.find_by(couch_id: mapper.order_uuid)
      if existing.present?
        log_info("[MaHIS CouchDB Orders] Already imported accession=#{mapper.tracking_number} couch_id=#{mapper.order_uuid}")
        return :already_imported
      end

      status, response = OrderManagement::OrdersService.create_order(mapper.payload, mapper.order_request?)
      unless status
        return fail_order(response, 'MaHIS CouchDB lab order import failed', patient_doc, order)
      end

      log_info("[MaHIS CouchDB Orders] Imported accession=#{mapper.tracking_number} couch_id=#{mapper.order_uuid} patient_doc=#{patient_doc['_id'] || patient_doc[:_id]}")
      :imported
    rescue StandardError => e
      fail_order(e.message, 'MaHIS CouchDB lab order import crashed', patient_doc, order)
    end

    def fail_order(error, message = nil, patient_doc = nil, order = nil)
      @last_error = error.to_s
      log_error(message, error, patient_doc, order) if message && patient_doc && order
      :failed
    end

    def mark_order_processed(order)
      before = status_fingerprint(order)
      order[STATUS_FIELD] = 'processed'
      order[DEAD_LETTER_FIELD] = false
      order[LAST_ERROR_FIELD] = nil
      order[FAILED_AT_FIELD] = nil
      order[PROCESSED_AT_FIELD] = Time.current.iso8601
      status_fingerprint(order) != before
    end

    def mark_order_failed(order, error)
      before = status_fingerprint(order)
      retry_count = order[RETRY_COUNT_FIELD].to_i + 1

      order[RETRY_COUNT_FIELD] = retry_count
      order[LAST_ERROR_FIELD] = error.to_s
      order[FAILED_AT_FIELD] = Time.current.iso8601
      order[PROCESSED_AT_FIELD] = nil

      if retry_count >= MAX_RETRY_ATTEMPTS
        order[STATUS_FIELD] = 'dead_letter'
        order[DEAD_LETTER_FIELD] = true
        log_warn("[MaHIS CouchDB Orders] Dead-lettered accession=#{order['accession_number'] || order[:accession_number]} error=#{error}")
      else
        order[STATUS_FIELD] = 'failed'
        order[DEAD_LETTER_FIELD] = false
      end

      status_fingerprint(order) != before
    end

    def status_fingerprint(order)
      [
        order[STATUS_FIELD],
        order[RETRY_COUNT_FIELD],
        order[LAST_ERROR_FIELD],
        order[FAILED_AT_FIELD],
        order[PROCESSED_AT_FIELD],
        order[DEAD_LETTER_FIELD]
      ]
    end

    def refresh_patient_pending_flags(patient_doc)
      before = [patient_doc[PENDING_FLAG], patient_doc[DEAD_LETTER_FLAG]]
      orders = lab_orders(patient_doc)
      patient_doc[PENDING_FLAG] = orders.any? { |order| retryable_order_status?(order) }
      patient_doc[DEAD_LETTER_FLAG] = orders.any? { |order| order.is_a?(Hash) && order[DEAD_LETTER_FIELD] == true }
      [patient_doc[PENDING_FLAG], patient_doc[DEAD_LETTER_FLAG]] != before
    end

    def retryable_order_status?(order)
      return false unless order.is_a?(Hash)
      return false if order[DEAD_LETTER_FIELD] == true

      PROCESSABLE_STATUSES.include?(order[STATUS_FIELD].to_s.presence)
    end

    def persist_status_changes(patient_doc)
      return if patient_doc['_id'].blank? || patient_doc['_rev'].blank?

      client.put_doc(patient_doc)
    rescue RestClient::Conflict, RestClient::PreconditionFailed
      log_warn("[MaHIS CouchDB Orders] Conflict while updating listener status for patient_doc=#{patient_doc['_id']}")
    rescue StandardError => e
      log_warn("[MaHIS CouchDB Orders] Unable to update listener status for patient_doc=#{patient_doc['_id']}: #{e.message}")
    end

    def log_error(message, error, patient_doc, order)
      log_warn("[MaHIS CouchDB Orders] #{message}: #{error}")
      return unless log_errors

      SyncErrorLog.create!(
        error_message: error,
        error_details: {
          message:,
          patient_doc_id: patient_doc['_id'] || patient_doc[:_id],
          accession_number: order['accession_number'] || order[:accession_number],
          order_uuid: order['operation_id'] || order[:operation_id] || order['offline_id'] || order[:offline_id]
        }
      )
    rescue StandardError => e
      log_warn("[MaHIS CouchDB Orders] Unable to log import error: #{e.message}")
    end
  end
end
