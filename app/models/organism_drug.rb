# frozen_string_literal: true

# This is the model for the organism drug table
class OrganismDrug < ApplicationRecord
  belongs_to :organism, class_name: 'Organism', foreign_key: 'organism_id'
  belongs_to :drug, class_name: 'Drug', foreign_key: 'drug_id'
end
