# frozen_string_literal: true

class TestTypeOrganism < ApplicationRecord
  include BumpsOwnerRevision

  belongs_to :test_type
  belongs_to :organism

  bumps_revision_of :test_type
end
