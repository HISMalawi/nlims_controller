# frozen_string_literal: true

# MeasureType model
class MeasureType < ApplicationRecord
  has_many :measures, dependent: :restrict_with_error, class_name: 'Measure'
end
