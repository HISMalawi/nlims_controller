# frozen_string_literal: true

class TestPanelTestType < ApplicationRecord
  include BumpsOwnerRevision

  belongs_to :test_panel
  belongs_to :test_type

  bumps_revision_of :test_panel
end
