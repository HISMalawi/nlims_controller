# frozen_string_literal: true

# The reference interval or expected value for an indicator, narrowed by age
# and sex. A result is interpreted against these, so they travel with the
# indicator.
class IndicatorRange < ApplicationRecord
  include BumpsOwnerRevision

  belongs_to :indicator

  bumps_revision_of :indicator

  validates :sex, inclusion: { in: %w[Both M F] }
end
