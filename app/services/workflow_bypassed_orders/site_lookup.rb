# frozen_string_literal: true

module WorkflowBypassedOrders
  # Finds the facility an order came from by its site code number
  module SiteLookup
    CODE_LENGTH = 4

    module_function

    # Site codes are 4 digits with a leading zero where needed ('0102'). A 3 digit code gets that zero added.
    def normalize(code)
      code = code.to_s.strip
      code.match?(/\A\d{#{CODE_LENGTH - 1}}\z/) ? code.rjust(CODE_LENGTH, '0') : code
    end

    # Name of the enabled site with this code, or nil. If several enabled sites share the code, the oldest wins.
    def facility_name(code)
      code = normalize(code)
      sites = Site.where(site_code_number: code, enabled: true).order(:id).limit(2).to_a
      Rails.logger.warn("More than one enabled site has site code number #{code}") if sites.size > 1
      sites.first&.name&.presence
    end
  end
end
