# frozen_string_literal: true

# A system allowed to call this node: an EMR at a health facility, a SISLAB
# installation at a laboratory, or another SISLAB Sync node.
#
# The client carries the facility and lab it belongs to, so a request never has
# to say which facility it is acting for — and cannot claim a different one.
class ApiClient < ApplicationRecord
  include HasUuid

  KINDS = %w[emr sislab node ui].freeze

  has_many :api_keys, dependent: :destroy

  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :facility_code, presence: true, if: :facility_scoped?

  scope :active, -> { where(active: true) }

  def facility_scoped?
    kind.in?(%w[emr sislab])
  end

  # A SISLAB client is pinned to one laboratory; an EMR speaks for the whole
  # facility and has no lab of its own.
  def acts_for_lab?(code)
    return true if lab_code.blank?

    lab_code == code
  end

  def acts_for_facility?(code)
    return true if facility_code.blank?

    facility_code == code
  end
end
