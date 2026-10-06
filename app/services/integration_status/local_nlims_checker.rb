# frozen_string_literal: true

module IntegrationStatus
  # Site with its own NLIMS next to the EMR: ICMP ping the server, ask the local NLIMS if it is up,
  # and ask it for the EMR vs NLIMS order counts.
  class LocalNlimsChecker < BaseChecker
    private

    def ping_method
      'icmp'
    end

    def unreachable_remark
      'NLIMS Local Not Reachable'
    end

    def check
      status = application_status
      errors = []
      summary = order_summary(errors)
      {
        ping_status: ping_server,
        app_status: status[:ping],
        app_version: status[:version],
        order_summary: summary,
        last_app_check_in_date: facts.last_check_in(site),
        check_errors: errors
      }
    end

    def base_url
      "http://#{site.host_address}:#{site.application_port}"
    end

    def configured?
      site.host_address.present? && site.application_port.present?
    end

    def ping_server
      return false if site.host_address.blank?

      Net::Ping::External.new(site.host_address, nil, timeout).ping?
    end

    def application_status
      return { ping: false, version: 'N/A' } unless configured?

      body = Http.request_json(method: :get, url: "#{base_url}/api/v1/ping?site_id=#{site.id}", timeout:)
      { ping: body['ping'] == true, version: body['version'].presence || 'N/A' }
    rescue RestClient::Exceptions::Timeout
      { ping: false, version: 'N/A' }
    rescue RestClient::NotFound
      legacy_application_status
    rescue StandardError
      { ping: false, version: 'N/A' }
    end

    # Older NLIMS versions have no /ping; a JSON reply from re_authenticate means the app is running.
    def legacy_application_status
      body = Http.request_json(method: :get, url: "#{base_url}/api/v1/re_authenticate/aexede/aexede", timeout:)
      { ping: body['error'].present?, version: 'N/A' }
    rescue StandardError
      { ping: false, version: 'N/A' }
    end

    def order_summary(errors)
      return unreachable_summary(unreachable_remark) unless configured?

      data = Http.request_json(
        method: :get,
        url: "#{base_url}/orders_summary",
        payload: {
          start_date: settings.summary_start_date,
          end_date: settings.summary_end_date,
          concept: settings.concept,
          include_data: false
        },
        timeout:
      ).deep_symbolize_keys
      chsu = nlims_chsu
      {
        emr: data[:emr],
        nlims_local: data[:nlims_local],
        nlims_chsu: chsu,
        overall_remark: OrderService.order_summary_remark(data[:emr], data[:nlims_local], nlims_chsu: chsu)
      }
    rescue StandardError => e
      errors << "Order summary: #{e.message}"
      unreachable_summary(unreachable_remark)
    end
  end
end
