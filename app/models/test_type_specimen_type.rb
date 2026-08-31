# frozen_string_literal: true

class TestTypeSpecimenType < ApplicationRecord
  include BumpsOwnerRevision

  belongs_to :test_type
  belongs_to :specimen_type

  bumps_revision_of :test_type
end
