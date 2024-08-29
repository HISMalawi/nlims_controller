# frozen_string_literal: true

# Config Model containing system configurations
class Config < ApplicationRecord
  validates :config_type, presence: true, uniqueness: true

  def self.local_nlims?
    find_by(config_type: 'nlims_host')&.configs&.dig('local_nlims')
  end
end
