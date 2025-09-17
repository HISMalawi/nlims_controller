# frozen_string_literal: true

# This is the model for the organism table
class Organism < ApplicationRecord
  include Codeable

  has_many :organism_drugs, dependent: :restrict_with_error, class_name: 'OrganismDrug'
  has_many :drugs, through: :organism_drugs
  has_many :testtype_organisms, class_name: 'TesttypeOrganism'
  has_paper_trail

  NLIMS_CODE_PREFIX = 'ORG'

  def as_json(options = {})
    super(options.merge(
      except: %i[],
      include: {
        drugs: {}
      }
    ))
  end
end
