# frozen_string_literal: true

# Model for recording application check-ins
class AppCheckIn < ApplicationRecord
  belongs_to :site, class_name: 'Site', optional: true

  validates :name, :check_in_time, presence: true
end
