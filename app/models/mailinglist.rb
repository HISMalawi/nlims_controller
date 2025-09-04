# frozen_string_literal: true

# Mailinglist model
class Mailinglist < ApplicationRecord
  validates :email, presence: true, uniqueness: true
end
