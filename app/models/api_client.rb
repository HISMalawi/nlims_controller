# frozen_string_literal: true

# A system allowed to call this node: an EMR at a health facility, a SISLAB
# installation at a laboratory, or another SISLAB Sync node.
#
# Issuing a key on a local node asks for no codes. The unit is the node's own
# and the register names it; the laboratory is not the key's business at all,
# since one mLab instance speaks for every laboratory in the unit under a single
# key and says which bench is asking in each request. A code typed into the form
# would only decide whether requests are answered or refused with a 403 that
# nobody can diagnose from the other end.
class ApiClient < ApplicationRecord
  include HasUuid

  KINDS = %w[emr sislab node ui].freeze

  has_many :api_keys, dependent: :destroy

  before_validation :adopt_node_identity, on: :create

  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }

  scope :active, -> { where(active: true) }

  def facility_scoped?
    kind.in?(%w[emr sislab])
  end

  private

  # Filled once, at issue, rather than read live: a key issued for this node
  # should go on meaning what it meant even if the register later renames the
  # unit, and the audit trail should show what was true when it was issued.
  #
  # The unit only. Which bench is asking travels with the request, because a
  # single key stands for every laboratory in the unit.
  def adopt_node_identity
    return unless SislabSync.local? && facility_scoped?

    self.facility_code = SislabSync.facility_code if facility_code.blank?
  end
end
