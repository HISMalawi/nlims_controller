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
    pending_acks = ResultsAcknwoledge.where(id: id, acknwoledged_to_nlims: false)
    pending_acks = nil if pending_acks.empty?
    master_nlims_service = MasterNlimsSyncService.new
    master_nlims_service.push_acknwoledgement_to_master_nlims(
      pending_acks: pending_acks
    )
  end
end
