# frozen_string_literal: true

module Api
  module V3
    # What this key is and what it may do. The first call an integrator makes,
    # and the fastest way to tell a wrong key from a wrong scope from a wrong
    # node when something does not work.
    class MeController < Api::BaseController
      def show
        client = Current.api_client
        key = Current.api_key

        render_data({
                      client: {
                        uuid: client.uuid,
                        name: client.name,
                        kind: client.kind,
                        facility_code: client.facility_code,
                        lab_code: client.lab_code
                      },
                      key: {
                        uuid: key.uuid,
                        token: key.masked_token,
                        scopes: key.scopes,
                        expires_at: key.expires_at&.iso8601,
                        last_used_at: key.last_used_at&.iso8601
                      },
                      node: {
                        mode: SislabSync.mode,
                        node_code: SislabSync.node_code,
                        facility_code: SislabSync.facility_code,
                        # The benches this unit holds, so an integrator can see
                        # at a glance which `lab_code` values its calls may
                        # carry — including the ones this node registered itself
                        # and the capital has not named yet.
                        labs: SislabSync.labs.map do |lab|
                          { code: lab.code, name: lab.name, national_code: lab.national_code }
                        end
                      }
                    })
      end
    end
  end
end
