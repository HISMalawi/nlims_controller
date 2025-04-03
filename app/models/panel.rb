# frozen_string_literal: true

# Panel model
class Panel < ApplicationRecord
  belongs_to :panel_type
  belongs_to :test_type
end
