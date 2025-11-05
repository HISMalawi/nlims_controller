# frozen_string_literal: true

# this is the model for the predefined results table
class PredefinedResult < ApplicationRecord
  include Codeable

  NLIMS_CODE_PREFIX = 'PDR'
end
