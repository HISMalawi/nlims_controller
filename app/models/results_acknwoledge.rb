# frozen_string_literal: true

# ResultsAcknwoledge Model
class ResultsAcknwoledge < ApplicationRecord
  after_commit :push_acknwoledgement_to_master_nlims, on: %i[create], if: :local_nlims?

  private

  def local_nlims?
    Config.local_nlims?
  end

  def push_acknwoledgement_to_master_nlims
    SyncWithNlimsJob.perform_async({
      identifier: id,
      type: 'acknowlegment',
      action: nil
    }.stringify_keys)
  end
end
