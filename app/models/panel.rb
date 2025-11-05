# frozen_string_literal: true

# Panel model
class Panel < ApplicationRecord
  belongs_to :panel_type
  belongs_to :test_type
  has_paper_trail
end
