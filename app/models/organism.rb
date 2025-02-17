# frozen_string_literal: true

# This is the model for the organism table
class Organism < ApplicationRecord
  include Codeable

  has_many :organism_drugs, dependent: :restrict_with_error, class_name: 'OrganismDrug'

  NLIMS_CODE_PREFIX = 'ORG'
end
