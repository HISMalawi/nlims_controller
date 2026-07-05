# frozen_string_literal: true

require 'digest'

module MahisCouchdb
  # Writes verified NLiMS results back to the matching MaHIS patient CouchDB doc.
  class ResultWriterService
    SOURCE_SYSTEM = 'mahis_couchdb'

    attr_reader :client, :indicator_client

    def self.mahis_couchdb_order?(specimen)
      specimen&.source_system.to_s.casecmp?(SOURCE_SYSTEM)
    end

    def initialize(client = Client.new, indicator_client: Client.new(database: 'test_result_indicators'))
      @client = client
      @indicator_client = indicator_client
      @indicator_metadata_cache = {}
    end

    def call(tracking_number:, test_id: nil)
      attempts = 0
      return false unless client.enabled?

      specimen = Speciman.find_by(tracking_number:)
      return false unless self.class.mahis_couchdb_order?(specimen)

      doc = find_patient_doc(specimen)
      return false unless doc

      changed = apply_results!(doc, specimen, test_id)
      return false unless changed

      doc['sync_status'] = 'unsynced'
      doc['processed_by_listener'] = false
      doc['nlims_result_synced_at'] = Time.current.iso8601
      client.put_doc(doc)
      true
    rescue RestClient::Conflict
      attempts += 1
      retry if attempts < 3

      log_error('MaHIS CouchDB result write-back failed', '409 Conflict', tracking_number, test_id)
      false
    rescue StandardError => e
      log_error('MaHIS CouchDB result write-back failed', e.message, tracking_number, test_id)
      false
    end

    private

    def find_patient_doc(specimen)
      patient_doc_id = specimen.tests.first&.patient&.patient_number
      return client.get_doc(patient_doc_id) if patient_doc_id.present?

      find_patient_doc_by_accession(specimen.tracking_number)
    rescue RestClient::NotFound
      find_patient_doc_by_accession(specimen.tracking_number)
    end

    def find_patient_doc_by_accession(tracking_number)
      selector = {
        '$or' => [
          { 'labOrders.unsaved' => { '$elemMatch' => { 'accession_number' => tracking_number } } },
          { 'labOrders.saved' => { '$elemMatch' => { 'accession_number' => tracking_number } } }
        ]
      }
      client.find(selector, limit: 1).fetch('docs', []).first
    rescue StandardError => e
      Rails.logger.warn("Unable to find MaHIS CouchDB patient doc for accession #{tracking_number}: #{e.message}")
      nil
    end

    def apply_results!(doc, specimen, test_id)
      order = matching_order(doc, specimen)
      return false unless order

      lab_results = (doc['labOrders'] ||= {})
      lab_results['results'] ||= []

      changed = false
      nlims_tests(specimen, test_id).each do |nlims_test|
        mahis_test = matching_test(order, nlims_test)
        next unless mahis_test

        measures = result_measures(nlims_test, mahis_test)
        next if measures.empty?

        mahis_test['result'] = merge_test_results(mahis_test['result'], measures)
        result_key = result_key(specimen, nlims_test, measures)
        existing_result = matching_result_entry(lab_results, order, mahis_test, result_key)
        if existing_result
          existing_result['measures'] = merge_test_results(existing_result['measures'], measures)
          existing_result['nlims_result_key'] = result_key
        else
          lab_results['results'] << pending_result_entry(order, mahis_test, measures, result_key)
        end
        changed = true
      end

      changed
    end

    def matching_order(doc, specimen)
      lab_orders = doc['labOrders'] || {}
      orders = Array.wrap(lab_orders['unsaved'] || lab_orders[:unsaved]) +
               Array.wrap(lab_orders['saved'] || lab_orders[:saved])
      orders.find do |order|
        order_data = order.with_indifferent_access
        order_data[:accession_number].to_s == specimen.tracking_number.to_s ||
          order_data[:tracking_number].to_s == specimen.tracking_number.to_s ||
          order_data[:offline_id].to_s == specimen.couch_id.to_s ||
          order_data[:operation_id].to_s == specimen.couch_id.to_s
      end
    end

    def nlims_tests(specimen, test_id)
      tests = specimen.tests.includes(:test_type, test_results: :measure)
      tests = tests.where(id: test_id) if test_id.present?
      tests
    end

    def matching_test(order, nlims_test)
      tests = Array.wrap(order['tests'] || order[:tests]).filter { |test| test.is_a?(Hash) }
      return nil if tests.empty?

      test_names = [nlims_test.test_type&.name, nlims_test.test_type&.preferred_name].compact.map { |name| normalize_name(name) }
      tests.find do |test|
        test = test.with_indifferent_access
        test[:uuid].to_s == nlims_test.uuid.to_s ||
          test[:test_uuid].to_s == nlims_test.uuid.to_s ||
          test_names.include?(normalize_name(test[:name] || test[:test_name]))
      end
    end

    def result_measures(nlims_test, mahis_test)
      test_concept_id = mahis_test.with_indifferent_access[:concept_id]
      nlims_test.test_results.filter_map do |test_result|
        next if test_result.result.blank?

        {
          'indicator' => result_indicator(test_result.measure, test_concept_id),
          'value' => test_result.result,
          'unit' => test_result.unit,
          'date' => test_result.time_entered,
          'value_modifier' => '',
          'value_type' => 'text',
          'source' => 'nlims'
        }.compact
      end
    end

    def result_indicator(measure, test_concept_id)
      metadata = indicator_metadata(measure&.nlims_code, test_concept_id)
      name = metadata['name'].presence || measure&.name

      {
        'name' => name,
        'concept' => name,
        'concept_id' => metadata['concept_id'],
        'nlims_code' => measure&.nlims_code || metadata['nlims_code'],
        'preferred_name' => measure&.preferred_name,
        'uuid' => metadata['uuid']
      }.compact
    end

    def indicator_metadata(nlims_code, test_concept_id)
      return {} if nlims_code.blank?

      cache_key = [nlims_code, test_concept_id.to_s].join(':')
      @indicator_metadata_cache[cache_key] ||= begin
        selector = { 'nlims_code' => nlims_code }
        selector['concept_set'] = test_concept_id.to_i if test_concept_id.to_i.positive?

        docs = indicator_client.find(selector, limit: 10).fetch('docs', [])
        docs.find { |doc| doc['concept_set'].to_s == test_concept_id.to_s } || docs.first || {}
      rescue StandardError => e
        Rails.logger.warn("Unable to map MaHIS indicator for NLIMS code #{nlims_code}: #{e.message}")
        {}
      end
    end

    def merge_test_results(existing_results, measures)
      merged = []
      existing = Array.wrap(existing_results).filter { |entry| entry.is_a?(Hash) }
      (existing + measures).each do |measure|
        match = merged.find { |entry| same_measure_result?(entry, measure) }
        if match
          merge_measure!(match, measure)
        else
          merged << measure
        end
      end
      merged
    end

    def merge_measure!(target, source)
      target['indicator'] = target.fetch('indicator', {}).merge(source.fetch('indicator', {}).compact)
      source.each do |key, value|
        next if key == 'indicator' || value.blank?

        target[key] = value
      end
      target
    end

    def same_measure_result?(left, right)
      left = left.with_indifferent_access
      right = right.with_indifferent_access
      left_code = left.dig(:indicator, :nlims_code).to_s
      right_code = right.dig(:indicator, :nlims_code).to_s
      same_indicator = if left_code.present? && right_code.present?
                         left_code == right_code
                       else
                         left.dig(:indicator, :name).to_s == right.dig(:indicator, :name).to_s
                       end

      same_indicator && left[:value].to_s == right[:value].to_s
    end

    def pending_result_entry(order, mahis_test, measures, result_key)
      order = order.with_indifferent_access
      mahis_test = mahis_test.with_indifferent_access
      {
        'encounter_id' => '',
        'date' => measures.filter_map { |measure| measure['date'] }.first || Time.current.iso8601,
        'measures' => measures,
        'test_id' => mahis_test[:id],
        'test_concept_id' => mahis_test[:concept_id],
        'offline_id' => order[:offline_id] || order[:operation_id],
        'accession_number' => order[:accession_number],
        'source' => 'nlims',
        'nlims_result_key' => result_key
      }.compact
    end

    def matching_result_entry(lab_results, order, mahis_test, result_key)
      order = order.with_indifferent_access
      mahis_test = mahis_test.with_indifferent_access
      Array.wrap(lab_results['results']).find do |entry|
        entry = entry.with_indifferent_access
        entry[:nlims_result_key].to_s == result_key ||
          (entry[:source].to_s == 'nlims' &&
            entry[:accession_number].to_s == order[:accession_number].to_s &&
            entry[:test_id].to_s == mahis_test[:id].to_s)
      end
    end

    def result_key(specimen, nlims_test, measures)
      Digest::SHA256.hexdigest("#{specimen.tracking_number}:#{nlims_test.id}:#{measures.to_json}")
    end

    def normalize_name(value)
      value.to_s.strip.downcase
    end

    def log_error(message, error, tracking_number, test_id)
      Rails.logger.warn("#{message}: #{error}")
      SyncErrorLog.create!(
        error_message: error,
        error_details: {
          message:,
          tracking_number:,
          test_id:
        }
      )
    rescue StandardError => e
      Rails.logger.warn("Unable to log MaHIS CouchDB result error: #{e.message}")
    end
  end
end
