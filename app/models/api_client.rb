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
  # should go on meaning what it meant even if the register later moves the
  # laboratory to a different facility code, and the audit trail should show
  # what was true when it was issued.
  def adopt_node_identity
    return unless SislabSync.local? && facility_scoped?

    self.lab_code = SislabSync.lab_code if lab_code.blank?
    self.facility_code = SislabSync.facility_code if facility_code.blank?
  end
end
