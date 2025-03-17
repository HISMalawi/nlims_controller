# frozen_string_literal: true

# MeasureRange model
class MeasureRange < ApplicationRecord
  belongs_to :measure, class_name: 'Measure', foreign_key: 'measures_id', inverse_of: :measure_ranges
  enum sex: { Male: 0, Female: 1, Both: 2 }
end
