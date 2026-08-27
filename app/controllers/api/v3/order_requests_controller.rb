# frozen_string_literal: true

module Api
  module V3
    # Where an EMR asks for tests.
    #
    # The reply is a receipt, not the order: the tracking number is what the EMR
    # writes on the sample tube and searches by afterwards, and everything else
    # about the order is one GET away.
    class OrderRequestsController < Api::BaseController
      def create
        return unless authorize_scope!("orders:write")

        order_request = OrderRequest.new(order_request_params, api_client: Current.api_client)
        return unless authorize_facility!(order_request.facility_code)

        idempotent do
          order = order_request.create!

          render_data(
            { tracking_number: order.tracking_number, order_uuid: order.uuid, status: order.status },
            status: :created
          )
        end
      end

      private

      def order_request_params
        payload.permit(
          patient: %i[national_id name sex birthdate phone],
          order: [
            :sending_facility_code, :receiving_lab_code, :lab_code, :priority, :requested_by,
            :order_location, :clinical_history, :collected_at,
            { specimen_type: Dictionary::Reference::ATTRIBUTES }
          ],
          tests: [
            :method_of_testing,
            { test_type: Dictionary::Reference::ATTRIBUTES, test_panel: Dictionary::Reference::ATTRIBUTES }
          ]
        )
      end
    end
  end
end
