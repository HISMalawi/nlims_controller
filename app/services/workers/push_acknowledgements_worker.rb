# frozen_string_literal: true

##
# Worker for pushing acknowledgements to NLIMS
class PushAcknowledgementsWorker
  def run
    return unless Config.local_nlims?

    Rails.logger.info('Starting acknowledgements push to NLIMS')

    SyncToNlimsService.push_acknwoledgement_to_master_nlims

    Rails.logger.info('Acknowledgements push completed successfully')
  rescue StandardError => e
    Rails.logger.error("Error pushing acknowledgements: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
