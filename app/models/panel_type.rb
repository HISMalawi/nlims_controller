# frozen_string_literal: true

# Panel type model
class PanelType < ApplicationRecord
  include Codeable

  NLIMS_CODE_PREFIX = 'TP'
end
