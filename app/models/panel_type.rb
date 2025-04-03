# frozen_string_literal: true

# Panel type model
class PanelType < ApplicationRecord
  has_many :panels, dependent: :restrict_with_error
  has_many :test_types, through: :panels

  include Codeable

  NLIMS_CODE_PREFIX = 'TP'

  def as_json(options = {})
    super(options.merge(include: { test_types: {} }))
  end
end
