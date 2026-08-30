# frozen_string_literal: true

# A health facility on the network, and the thing a local node is.
#
# One installation serves one unit. Every laboratory inside it — mLab holds
# several, each under its own code — reaches the country through this one node,
# and every sample raised here is addressed to the unit before any laboratory
# has claimed it.
#
# The register is the capital's. A node learns its own name, district and
# province by reading the entry the capital published for it, which is why an
# installation only has to be told its code.
class Facility < ApplicationRecord
  include DictionaryEntry

  self.national_code_prefix = "FAC"

  has_many :labs, -> { ordered }, primary_key: :national_code, foreign_key: :facility_code,
                                 inverse_of: :facility, dependent: nil

  scope :ordered, -> { order(:name) }

  # The unit this node is. Nil until the register has been pulled — a first
  # install, or a node the capital has not published yet — and every caller
  # copes, because a unit that cannot take samples until the capital has heard
  # of it is a unit that cannot work.
  def self.this_node
    find_by(national_code: SislabSync.facility_code)
  end

  def place
    [ district, province ].compact_blank.join(", ")
  end

  def label
    [ national_code, name ].compact_blank.join(" — ")
  end
end
