# frozen_string_literal: true

# # This is the model for the specimen dispatch table
class SpecimenDispatch < ApplicationRecord
  include Codeable

  NLIMS_CODE_PREFIX = 'SD'
end
