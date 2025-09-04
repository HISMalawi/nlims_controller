# frozen_string_literal: true

# Service class for syncing order results and statuses between master nlims and local nlims
module SyncUtilService
  def self.ack_result_at_facility_level(track_n, test_id, result_date, level, ack_by)
    return unless acknowledged_already?(track_n, ack_by)

    ResultsAcknwoledge.create(
      tracking_number: track_n,
      test_id:,
      acknwoledged_at: Time.new.strftime('%Y%m%d%H%M%S'),
      result_date:,
      acknwoledged_by: ack_by,
      acknwoledged_to_nlims: false,
      acknowledgment_level: level
    )
    test_record = Test.find_by(id: test_id)
    test_record.update(
      result_given: 0,
      date_result_given: Time.new.strftime('%Y%m%d%H%M%S'),
      test_result_receipent_types: level
    )
  end

  def self.acknowledged_already?(tracking_number, acknowledge_by)
    ResultsAcknwoledge.find_by(
      tracking_number:,
      acknwoledged_by: acknowledge_by
    ).nil?
  end

  def self.log_error(error_message: nil, custom_message: nil, payload: nil)
    log = SyncErrorLog.create(
      error_message:,
      error_details: { message: custom_message, payload: }
    )
    raise StandardError, log.to_json
  end
end
