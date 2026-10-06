# frozen_string_literal: true

module IntegrationStatus
  # Everything a checker needs from the master database, loaded with a few grouped queries up front
  # so the network checks can run in threads without touching the connection pool.
  class SiteFacts
    def self.prefetch(sites, settings)
      names = sites.map(&:name)
      new(
        last_syncs: Speciman.where(sending_facility: names).group(:sending_facility).maximum(:created_at),
        check_ins: AppCheckIn.where(site_id: sites.map(&:id)).group(:site_id).maximum(:check_in_time),
        nlims_chsu_counts: OrderService.nlims_orders_count_by_facility(
          settings.summary_start_date, settings.summary_end_date, settings.concept, names
        )
      )
    end

    def initialize(last_syncs:, check_ins:, nlims_chsu_counts:)
      @last_syncs = last_syncs
      @check_ins = check_ins
      @nlims_chsu_counts = nlims_chsu_counts
    end

    def last_sync_date(site)
      @last_syncs[site.name]
    end

    def last_check_in(site)
      @check_ins[site.id]
    end

    def nlims_chsu_count(site)
      @nlims_chsu_counts[site.name] || 0
    end
  end
end
