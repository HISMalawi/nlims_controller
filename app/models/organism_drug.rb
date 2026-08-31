# frozen_string_literal: true

class OrganismDrug < ApplicationRecord
  include BumpsOwnerRevision

  belongs_to :organism
  belongs_to :drug

  bumps_revision_of :organism
end
