# frozen_string_literal: true

# this is the model for the drug table
class Drug < ApplicationRecord
  include Codeable

  has_many :organism_drugs, dependent: :restrict_with_error, class_name: 'OrganismDrug'

  NLIMS_CODE_PREFIX = 'DRG'
end
