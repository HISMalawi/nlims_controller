# frozen_string_literal: true

class TestTypeIndicator < ApplicationRecord
  include BumpsOwnerRevision

  belongs_to :test_type
  belongs_to :indicator

  bumps_revision_of :test_type
end
