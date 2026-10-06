# frozen_string_literal: true

module IntegrationStatus
  # Builds one row of the integration status report. Subclasses fill in the mode-specific parts;
  # the row shape is identical for every mode so the dashboard and PowerBI read them the same way.
  class BaseChecker
    NEVER_SYNCED = 'Has Never Synced with NLIMS'
    TIME_FORMAT = '%d/%b/%Y %H:%M'

    attr_reader :site, :settings, :facts

    def initialize(site:, settings:, facts:)
      @site = site
      @settings = settings
      @facts = facts
    end

    # Never raises: a failed check still produces a row so the site doesn't vanish from the report.
    def call
      base_row.merge(check).as_json
    rescue StandardError => e
      Rails.logger.error("[IntegrationStatus] #{site.name}: #{e.class} #{e.message}")
      base_row.merge(failed_check(e)).as_json
    end

    private

    def check
      raise NotImplementedError
    end

    def ping_method
      raise NotImplementedError
    end

    def unreachable_remark
      raise NotImplementedError
    end

    def base_row
      last_sync = facts.last_sync_date(site)
      {
        name: site.name,
        district: site.district,
        integration_mode: site.integration_mode,
        emr_instance: nil,
        ip_address: site.host_address,
        app_port: site.application_port,
        ping_method:,
        ping_status: false,
        app_status: false,
        app_version: 'N/A',
        status_last_updated: Time.now.strftime(TIME_FORMAT),
        last_sync_date_gt_24hr: last_sync.nil? || last_sync < settings.stale_sync_hours.hours.ago,
        last_sync_date: last_sync ? last_sync.strftime(TIME_FORMAT) : NEVER_SYNCED,
        order_summary: unreachable_summary(unreachable_remark),
        last_app_check_in_date: nil,
        check_errors: []
      }
    end

    def failed_check(error)
      { check_errors: ["#{error.class}: #{error.message}"] }
    end

    def nlims_chsu
      { count: facts.nlims_chsu_count(site), lab_orders: [] }
    end

    def unreachable_summary(remark)
      {
        emr: { count: 0, last_order_date: nil, lab_orders: [], remark: },
        nlims_local: { count: 0, lab_orders: [] },
        nlims_chsu:,
        overall_remark: remark
      }
    end

    def timeout
      settings.http_timeout_seconds
    end
  end
end
