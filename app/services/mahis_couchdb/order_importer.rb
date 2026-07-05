# frozen_string_literal: true

module MahisCouchdb
  # Imports MaHIS patient-record lab orders into the local NLiMS database.
  class OrderImporter
    attr_reader :client

    def initialize(client = Client.new)
      @client = client
    end

    def import_patient_doc(patient_doc)
      return 0 unless patient_doc.is_a?(Hash)

      lab_orders(patient_doc).sum { |order| import_order(patient_doc, order) ? 1 : 0 }
    end

    private

    def lab_orders(patient_doc)
      lab_orders = (patient_doc['labOrders'] || patient_doc[:labOrders] || {}).with_indifferent_access
      Array.wrap(lab_orders[:unsaved]) + Array.wrap(lab_orders[:saved])
    end

    def import_order(patient_doc, order)
      return false unless order.is_a?(Hash)

      mapper = LabOrderMapper.new(client.config, patient_doc, order)
      return false if mapper.tracking_number.blank?

      unless mapper.valid?
        log_error('MaHIS CouchDB lab order skipped', mapper.errors.join(', '), patient_doc, order)
        return false
      end

      existing = Speciman.find_by(tracking_number: mapper.tracking_number) || Speciman.find_by(couch_id: mapper.order_uuid)
      return false if existing.present?

      status, response = OrderManagement::OrdersService.create_order(mapper.payload, mapper.order_request?)
      unless status
        log_error('MaHIS CouchDB lab order import failed', response, patient_doc, order)
        return false
      end

      Rails.logger.info("Imported MaHIS CouchDB lab order #{mapper.tracking_number} into NLiMS")
      true
    rescue StandardError => e
      log_error('MaHIS CouchDB lab order import crashed', e.message, patient_doc, order)
      false
    end

    def log_error(message, error, patient_doc, order)
      Rails.logger.warn("#{message}: #{error}")
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
      Rails.logger.warn("Unable to log MaHIS CouchDB import error: #{e.message}")
    end
  end
end
