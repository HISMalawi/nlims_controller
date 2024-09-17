# frozen_string_literal: true

require 'master_nlims_sync_service'

# ResultsAcknwoledge Model
class ResultsAcknwoledge < ApplicationRecord
  after_commit :push_acknwoledgement_to_master_nlims, if: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_acknwoledgement_to_master_nlims
    acknowledgement = ResultsAcknwoledge.find_by(id:)
    SyncWithNlimsJob.perform_async(acknowledgement, type: 'acknowlegment')
  end
end
