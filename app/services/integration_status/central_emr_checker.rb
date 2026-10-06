# frozen_string_literal: true

module IntegrationStatus
  # Site whose EMR is a central deployment (MaHIS) that sends orders straight to master NLIMS.
  # The central server can't be pinged, so its HTTP health endpoint stands in for ping and app status,
  # and EMR order counts come from the central EMR filtered by the site's location.
  class CentralEmrChecker < BaseChecker
    # client is nil when the site has no active EMR instance
    def initialize(client:, **kwargs)
      super(**kwargs)
      @client = client
    end

    private

    def ping_method
      'http_health'
    end

    def unreachable_remark
      'MaHIS Not Reachable'
    end

    def check
      instance = site.emr_instance
      return misconfigured('Site has no central EMR instance') if instance.nil?

      location = { emr_instance: instance.name, ip_address: instance.host, app_port: instance.port&.to_s }
      return location.merge(misconfigured("Central EMR instance '#{instance.name}' is disabled")) if @client.nil?

      health = @client.health
      emr = @client.order_summary(
        location_id: site.mahis_location_id,
        start_date: settings.summary_start_date,
        end_date: settings.summary_end_date,
        concept_id: instance.vl_concept_id
      )
      ok = emr.delete(:ok)
      chsu = nlims_chsu
      errors = []
      errors << "Health: #{health[:error]}" if health[:error].present?
      errors << emr[:remark] unless ok

      location.merge(
        ping_status: health[:reachable],
        app_status: health[:up],
        app_version: @client.version,
        order_summary: {
          emr:,
          # No local NLIMS in this setup; mirror the master count so consumers keep a numeric value
          nlims_local: chsu.merge(applicable: false),
          nlims_chsu: chsu,
          overall_remark: ok ? OrderService.order_summary_remark(emr, chsu) : emr[:remark]
        },
        check_errors: errors
      )
    end

    def unreachable_summary(remark)
      super.merge(nlims_local: nlims_chsu.merge(applicable: false))
    end

    def misconfigured(message)
      { order_summary: unreachable_summary(message), check_errors: [message] }
    end
  end
end
