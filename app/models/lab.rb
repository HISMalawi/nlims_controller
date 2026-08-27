# frozen_string_literal: true

# A laboratory on the network.
#
# The national node knows every laboratory in the country and publishes the list
# down the dictionary feed, so a local node can name another laboratory without
# anybody typing a code into a form. That is what makes a referral possible with
# nothing but the destination's code: everything else about it — the health
# facility, the district, who to call — is already here.
class Lab < ApplicationRecord
  include DictionaryEntry

  self.national_code_prefix = "LAB"

  scope :ordered, -> { order(:name) }

  # The laboratory this node is. Nil on a node whose code is not in the register
  # yet — a first install, or a node ahead of the national list — and every
  # caller is written to cope, because a laboratory that cannot receive orders
  # until the capital has heard of it is a laboratory that cannot work.
  def self.this_node
    find_by(national_code: SislabSync.lab_code)
  end

  # Where a sample sent here ends up. The facility code is what tracking numbers
  # and the older integrations are addressed by; a register entry without one
  # falls back to the laboratory's own code so nothing is left blank.
  def facility
    facility_code.presence || national_code
  end

  def place
    [ district, province ].compact_blank.join(", ")
  end

  def label
    [ national_code, name ].compact_blank.join(" — ")
  end
end
