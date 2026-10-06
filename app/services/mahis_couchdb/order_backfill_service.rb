# frozen_string_literal: true

module MahisCouchdb
  # Retries failed MaHIS CouchDB order imports that were captured in SyncErrorLog.
  class OrderBackfillService
    include ActivityLogger

    ORDER_ERROR_MESSAGES = [
      'MaHIS CouchDB lab order skipped',
      'MaHIS CouchDB lab order import failed',
      'MaHIS CouchDB lab order import crashed'
    ].freeze

    def initialize(client = Client.new)
      @client = client
      @importer = OrderImporter.new(client, log_errors: false)
    end

    def call(limit: 100)
      unless client.enabled?
        log_warn('[MaHIS CouchDB Backfill] Skipped because MaHIS CouchDB integration is disabled')
        return result(enabled: false)
      end

      logs = candidate_logs(limit)
      stats = result(enabled: true, scanned: logs.size)
      log_info("[MaHIS CouchDB Backfill] Retrying failed order imports count=#{logs.size}")

      logs.each do |log|
        retry_log(log, stats)
      end

      stats
    end

    private

    attr_reader :client, :importer

    def result(enabled:, scanned: 0)
      {
        enabled:,
        scanned:,
        retried: 0,
        imported: 0,
        resolved: 0,
        failed: 0,
        missing_doc: 0
      }
    end

    def candidate_logs(limit)
      requested_limit = positive_limit(limit)
      scan_limit = [requested_limit * 5, requested_limit].max

      SyncErrorLog.order(:created_at).limit(scan_limit).select do |log|
        ORDER_ERROR_MESSAGES.include?(details_for(log)[:message].to_s)
      end.first(requested_limit)
    end

    def positive_limit(limit)
      value = limit.to_i
      value.positive? ? value : 100
    end

    def retry_log(log, stats)
      details = details_for(log)

      if order_exists?(details)
        log_info("[MaHIS CouchDB Backfill] Resolved existing order accession=#{details[:accession_number]} order_uuid=#{details[:order_uuid]}")
        resolve_log(log, stats)
        return
      end

      patient_doc_id = details[:patient_doc_id].to_s
      if patient_doc_id.blank?
        stats[:failed] += 1
        return
      end

      stats[:retried] += 1
      imported = importer.import_patient_doc(client.get_doc(patient_doc_id))
      stats[:imported] += imported

      if imported.positive? || order_exists?(details)
        log_info("[MaHIS CouchDB Backfill] Resolved failed order accession=#{details[:accession_number]} patient_doc=#{patient_doc_id} imported=#{imported}")
        resolve_log(log, stats)
      else
        log_warn("[MaHIS CouchDB Backfill] Still failed accession=#{details[:accession_number]} patient_doc=#{patient_doc_id}")
        stats[:failed] += 1
      end
    rescue RestClient::NotFound
      stats[:missing_doc] += 1
      log_warn("[MaHIS CouchDB Backfill] Patient doc not found: #{details[:patient_doc_id]}")
    rescue StandardError => e
      stats[:failed] += 1
      log_warn("[MaHIS CouchDB Backfill] Failed: #{e.message}")
    end

    def resolve_log(log, stats)
      log.destroy
      stats[:resolved] += 1
    end

    def order_exists?(details)
      accession_number = details[:accession_number].to_s
      order_uuid = details[:order_uuid].to_s

      Speciman.exists?(tracking_number: accession_number) ||
        (order_uuid.present? && Speciman.exists?(couch_id: order_uuid))
    end

    def details_for(log)
      details = log.error_details || {}
      details = JSON.parse(details) if details.is_a?(String)
      details.with_indifferent_access
    rescue JSON::ParserError
      {}.with_indifferent_access
    end
  end
end
