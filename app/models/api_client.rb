# frozen_string_literal: true

# A system allowed to call this node: an EMR at a health facility, a SISLAB
# installation at a laboratory, or another SISLAB Sync node.
#
# Issuing a key used to mean typing a facility code and a laboratory code into a
# form, and those two strings then decided whether the client's requests were
# answered or refused with a 403 nobody could diagnose from the other end. On a
# node that is a laboratory, both are already known: the node's own code, and
# the health facility its register entry names. So they are taken from there and
# the form no longer asks.
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
  # Only the unit. A key used to carry a laboratory too, from when a node was
  # one; an mLab instance speaks for every laboratory in the unit under a single
  # key, so a laboratory on the key would be right for one of them and wrong for
  # the rest. Which bench is asking travels with the request instead.
  def adopt_node_identity
    return unless SislabSync.local? && facility_scoped?

    self.facility_code = SislabSync.facility_code if facility_code.blank?
  end
end
