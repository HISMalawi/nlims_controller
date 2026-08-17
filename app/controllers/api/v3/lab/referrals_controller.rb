# frozen_string_literal: true

module Api
  module V3
    module Lab
      # Sending a sample on, and taking one in.
      #
      # A district laboratory that cannot run a test today sends the sample to
      # one that can. Today that happens by road and by telephone, and the
      # clinic that took the sample loses sight of it entirely.
      class ReferralsController < Api::BaseController
        def create
          return unless authorize_scope!("referrals:write")
          return unless load_order
          return unless destination

          referral = Referral.dispatch!(
            order: @order,
            to_facility_code: destination[:to_facility_code],
            to_lab_code: destination[:to_lab_code],
            courier: referral_params[:courier],
            remarks: referral_params[:remarks],
            actor: actor
          )

          render_data(ReferralSerializer.call(referral), status: :created)
        end

        def update
          return unless authorize_scope!("referrals:write")

          referral = Referral.find_by!(uuid: params[:uuid])
          return unless authorize_lab!(referral.to_lab_code)

          settle(referral)
        rescue Referral::AlreadySettled => e
          render_api_error(Errors::CONFLICT, message: e.message)
        end

        private

        # The receiving laboratory says what happened to the parcel. Anything
        # else is refused rather than guessed at.
        def settle(referral)
          case params[:state]
          when Referral::RECEIVED
            referral.receive!(actor: actor, remarks: referral_params[:remarks])
          when Referral::REJECTED
            reason = Dictionary.entry!("rejection_reasons", params[:reason], field: "reason")
            referral.reject!(reason: reason, actor: actor, remarks: referral_params[:remarks])
          else
            return render_api_error(Errors::UNPROCESSABLE,
                                    message: "state tem de ser #{Referral::RECEIVED} ou #{Referral::REJECTED}",
                                    field: "state")
          end

          render_data(ReferralSerializer.call(referral))
        end

        def load_order
          @order = Order.find_by_tracking_number!(referral_params[:tracking_number].to_s)

          authorize_lab!(@order.receiving_lab_code)
        end

        def destination
          return @destination if defined?(@destination)

          to_facility = referral_params[:to_facility_code].presence
          to_lab = referral_params[:to_lab_code].presence
          @destination = { to_facility_code: to_facility, to_lab_code: to_lab }

          return @destination if to_facility && to_lab

          render_api_error(Errors::UNPROCESSABLE,
                           message: "é preciso indicar to_facility_code e to_lab_code",
                           field: to_facility ? "to_lab_code" : "to_facility_code")
          @destination = nil
        end

        def actor
          params[:actor].presence || Current.api_client.name
        end

        def referral_params
          params.permit(:tracking_number, :to_facility_code, :to_lab_code, :courier, :remarks, :state, :actor)
        end
      end
    end
  end
end
