# frozen_string_literal: true

# One referral on the wire.
class ReferralSerializer
  def self.call(referral)
    return if referral.nil?

    {
      uuid: referral.uuid,
      tracking_number: referral.tracking_number,
      state: referral.state,
      from_facility_code: referral.from_facility_code,
      from_lab_code: referral.from_lab_code,
      to_facility_code: referral.to_facility_code,
      to_lab_code: referral.to_lab_code,
      dispatched_at: referral.dispatched_at&.iso8601,
      received_at: referral.received_at&.iso8601,
      rejected_at: referral.rejected_at&.iso8601,
      rejection_reason: DictionaryReference.call(referral.rejection_reason_reference),
      courier: referral.courier,
      remarks: referral.remarks
    }
  end
end
