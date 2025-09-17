# frozen_string_literal: true

# this is the model for the drug table
class Drug < ApplicationRecord
  include Codeable

  has_many :organism_drugs, dependent: :restrict_with_error, class_name: 'OrganismDrug'
  has_many :organisms, through: :organism_drugs
  has_paper_trail

  NLIMS_CODE_PREFIX = 'DRG'
end
