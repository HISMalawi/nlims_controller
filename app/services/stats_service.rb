# frozen_string_literal: true

# StatsService class for stats
module StatsService
  class << self
    def get_latest_orders_by_site
      orders = Speciman.find_by_sql(
        "SELECT
            sending_facility,
            MAX(tracking_number) AS tracking_number,
            DATE(MAX(date_created)) date_order_created_emr,
            MAX(created_at) date_order_created_in_nlims
        FROM
            specimen
        WHERE date_created >= '2024-01-01'
        GROUP BY sending_facility
        ORDER BY date_order_created_in_nlims DESC"
      )
      orders.map do |order|
        {
          sending_facility: order.sending_facility,
          tracking_number: order.tracking_number,
          date_order_created_emr: order.date_order_created_emr,
          date_order_created_in_nlims: order.date_order_created_in_nlims
        }
      end
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
            MAX(s.tracking_number) tracking_number,
            MAX(tr.time_entered) max_results_date_eid_vl,
            MAX(tr.created_at) max_result_date_nlims
          FROM
            specimen s INNER JOIN tests t ON t.specimen_id = s.id
            INNER JOIN test_results tr ON tr.test_id = t.id AND tr.measure_id = 294
          WHERE s.date_created >= '2024-01-01'
          GROUP BY s.sending_facility
          ORDER BY max_result_date_nlims DESC"
        )
      results.map do |result|
        {
          sending_facility: result.sending_facility,
          tracking_number: result.tracking_number,
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
            tr.created_at max_result_date_nlims
          FROM
            specimen s INNER JOIN tests t ON t.specimen_id = s.id
            INNER JOIN test_results tr ON tr.test_id = t.id AND tr.measure_id = 294
         WHERE s.tracking_number=#{tracking_number}"
        )
      results.map do |result|
        {
          sending_facility: result.sending_facility,
          tracking_number: result.tracking_number,
          max_results_date_eid_vl: result.max_results_date_eid_vl,
          max_result_date_nlims: result.max_result_date_nlims
        }
      end
    end
  end
end
