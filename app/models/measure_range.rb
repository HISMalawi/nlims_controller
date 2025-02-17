# frozen_string_literal: true

# MeasureRange model
class MeasureRange < ApplicationRecord
  belongs_to :measure, class_name: 'Measure', foreign_key: 'measure_id'
end
