# frozen_string_literal: true

# StatsService class for stats
module StatsService
  class << self
    DATE_CREATED = Date.today - 6.months
    def get_latest_orders_by_site
      orders = Speciman.find_by_sql(
        "SELECT
            sending_facility,
            DATE(MAX(date_created)) date_order_created_emr,
            MAX(created_at) date_order_created_in_nlims
        FROM
            specimen
        WHERE date_created >= '#{DATE_CREATED}'
        GROUP BY sending_facility
        ORDER BY date_order_created_in_nlims DESC"
      )
      orders.map do |order|
        {
          sending_facility: order.sending_facility,
          tracking_number: Speciman.where(
            sending_facility: order.sending_facility
          ).where("DATE(date_created) = DATE('#{order.date_order_created_emr}')").last&.tracking_number,
          date_order_created_emr: order.date_order_created_emr,
          date_order_created_in_nlims: order.date_order_created_in_nlims
        }
      end
    end

    def integrated_sites
      enabled_sites = Site.where(enabled: true).order(:name).pluck(:name)

      # Step 1: Get latest sync for sites that have Specimen records
      latest_syncs = Speciman
                     .where(sending_facility: enabled_sites)
                     .group(:sending_facility)
                     .maximum(:created_at)

      # Step 2: Get integration status data and last update time
      integration_status_report = Report.where(name: 'integration_status').first
      integration_status_data = integration_status_report&.data || []
      integration_status_hash = integration_status_data.index_by { |site| site['name'] }
      integration_status_last_update = integration_status_report&.updated_at

      # Step 3: Merge with all enabled sites
      sites_data = enabled_sites.map do |site_name|
        last_sync = latest_syncs[site_name]
        site = Site.find_by(name: site_name)
        integration_status = integration_status_hash[site_name] || {}

        {
          sending_facility: site_name,
          district: site&.district,
          ip_address: site&.host_address,
          port: site&.application_port,
          app_status: integration_status['app_status'] || false ? 'Running' : 'Down',
          ping_status: integration_status['ping_status'] || false ? 'Success' : 'Failed',
          last_sync: last_sync ? last_sync.strftime('%d/%b/%Y %H:%M') : 'Has Never Synced with NLIMS',
          is_gt_24hr: last_sync.nil? || last_sync < 24.hours.ago
        }
      end

      # Step 4: Return segregated data with last update information
      {
        data: sites_data,
        integration_status_last_update: integration_status_last_update ? integration_status_last_update.strftime('%d/%b/%Y %H:%M') : 'Never Updated'
      }
    end

    def search_orders(tracking_number)
      Speciman.where(tracking_number:)
    end

    def get_total_orders_by_date(from, to, sending_facility)
      Speciman.where('Date(date_created) BETWEEN ? AND ?', from, to).where(sending_facility:).count
    end

    def get_latest_results_by_site
      results = Speciman.find_by_sql(
        "SELECT
            s.sending_facility,
            MAX(tr.time_entered) max_results_date_eid_vl,
            MAX(tr.created_at) max_result_date_nlims
          FROM
            specimen s INNER JOIN tests t ON t.specimen_id = s.id
            INNER JOIN test_results tr ON tr.test_id = t.id AND tr.measure_id = 294
          WHERE s.date_created >= '#{DATE_CREATED}'
          GROUP BY s.sending_facility
          ORDER BY max_result_date_nlims DESC"
      )
      results.map do |result|
        {
          sending_facility: result.sending_facility,
          tracking_number: Speciman.find_by(id: Test.find_by(id: TestResult.where(created_at: result.max_result_date_nlims).last&.test_id)&.specimen_id)&.tracking_number,
          max_results_date_eid_vl: result.max_results_date_eid_vl,
          max_result_date_nlims: result.max_result_date_nlims
        }
      end
    end

    def search_results(tracking_number)
      return [] unless tracking_number.present?

      results = Speciman.find_by_sql(
        "SELECT
            s.sending_facility,
            s.tracking_number,
            tr.time_entered max_results_date_eid_vl,
            tr.created_at max_result_date_nlims,
            trrt.name
          FROM
            specimen s INNER JOIN tests t ON t.specimen_id = s.id
            INNER JOIN test_results tr ON tr.test_id = t.id AND tr.measure_id = 294
            LEFT JOIN test_result_recepient_types trrt on trrt.id = t.test_result_receipent_types
         WHERE s.tracking_number='#{tracking_number}'"
      )
      results.map do |result|
        {
          sending_facility: result.sending_facility,
          tracking_number: result.tracking_number,
          max_results_date_eid_vl: result.max_results_date_eid_vl,
          max_result_date_nlims: result.max_result_date_nlims,
          ack_type: result.name
        }
      end
    end

    def count_by_sending_facility(from, to)
      from ||= Date.today
      to ||= Date.today
      {
        from:,
        to:,
        data: Speciman.where("DATE(date_created) BETWEEN '#{from}' AND '#{to}'").group(:sending_facility).count
      }
    end

    def orders_per_sending_facility(from, to, sending_facility)
      from ||= Date.today
      to ||= Date.today
      {
        from:,
        to:,
        data: Speciman.where("DATE(date_created) BETWEEN '#{from}' AND '#{to}'").where(sending_facility:).order(date_created: :desc).limit(1000)
      }
    end

    def sites
      Speciman.where("DATE(date_created) > '#{DATE_CREATED}'").order(:sending_facility).distinct.pluck(:sending_facility)
    end
  end
end
